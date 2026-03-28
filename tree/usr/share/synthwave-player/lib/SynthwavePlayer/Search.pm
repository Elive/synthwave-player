package SynthwavePlayer::Search;

use strict;
use warnings;
use utf8;
use Exporter 'import';
use SynthwavePlayer::Config;
use SynthwavePlayer::Utils qw(:DEFAULT _natural_compare _is_matched _stash_notification SONG_ID SONG_TITLE SONG_ARTIST SONG_ALBUM SONG_GENRE SONG_DURATION SONG_RATING SONG_LOCATION SONG_TRACKNUM SONG_BITRATE);

our @EXPORT_OK = qw(
    _get_processed_songs _get_initial_song_ids_from_context
    _highlight_fuzzy_diff _min3 _levenshtein_distance _normalize_for_search
    rank_search_results search_songs _highlight_substring
);

# Processes a list of song IDs with filtering, sorting, and pagination
sub _get_processed_songs {
    my ($c, $initial_song_ids_ref, $opts) = @_;
    my $sql = $c->app->sql;
    my $disable_sort = $opts && $opts->{disable_sort};
    my $matches_by_id = $opts && $opts->{matches};
    my $preserve_order = $opts && $opts->{preserve_order};

    # Parameters from request
    my $page = $c->param('page') || 1;
    my $limit = $c->param('limit') || $SONGS_PER_PAGE;
    my $ratings_filter_str = $c->param('ratings');
    my $sort_param = $c->param('sort');
    my $shuffle_param = $c->param('shuffle');

    my ($sort_by, $sort_dir);
    if ($sort_param && $sort_param =~ /^(\w+)(?:\|(asc|desc))?$/i) {
        my $requested_sort = lc($1);
        # Validate sort column against whitelist to prevent SQL injection
        my %valid_sort_columns = map { $_ => 1 } qw(title artist album genre duration rating track_number bitrate);
        $sort_by = $valid_sort_columns{$requested_sort} ? $requested_sort : $DEFAULT_SORT_BY;
        $sort_dir = lc($2 || 'asc');
        # Validate sort direction
        $sort_dir = ($sort_dir eq 'desc') ? 'desc' : 'asc';
    } else {
        $sort_by = $DEFAULT_SORT_BY;
        $sort_dir = $DEFAULT_SORT_ORDER;
    }

    # If preserve_order is set, we must handle filtering and pagination in Perl
    # to maintain the specific order of IDs passed in (e.g., search relevance).
    if ($preserve_order && $initial_song_ids_ref) {
        # We need to fetch metadata for these IDs to perform filtering (ratings)
        # We only fetch the columns needed for filtering to save memory.
        my %song_meta;
        if (@$initial_song_ids_ref) {
            my $in_clause = join(',', ('?') x @$initial_song_ids_ref);
            my $rows = $sql->db->query("SELECT id, rating FROM songs WHERE id IN ($in_clause)", @$initial_song_ids_ref)->hashes;
            %song_meta = map { $_->{id} => $_ } @$rows;
        }

        my @filtered_ids;
        for my $id (@$initial_song_ids_ref) {
            my $meta = $song_meta{$id};
            next unless $meta; # Should exist, but safety check

            # Apply Rating Filter
            if (defined $ratings_filter_str && length $ratings_filter_str) {
                my @ratings = split /\|/, $ratings_filter_str;
                @ratings = grep { /^\d+$/ && $_ >= 0 && $_ <= 5 } @ratings;
                if (@ratings) {
                    my %allowed_ratings = map { $_ => 1 } @ratings;
                    next unless exists $allowed_ratings{$meta->{rating} // 0};
                }
            }

            push @filtered_ids, $id;
        }

        my $total_songs = scalar @filtered_ids;
        my @page_ids;
        if (defined $limit && $limit == 0) {
            @page_ids = @filtered_ids;
        } else {
            my $offset = ($page - 1) * $limit;
            my $end = $offset + $limit - 1;
            $end = $#filtered_ids if $end > $#filtered_ids;

            if ($offset <= $#filtered_ids) {
                @page_ids = @filtered_ids[$offset .. $end];
            }
        }

        # Fetch full data for the paginated subset
        my @songs;
        if (@page_ids) {
            # We need to preserve the order of @page_ids in the result
            my $in_clause = join(',', ('?') x @page_ids);
            my $rows = $sql->db->query("SELECT * FROM songs WHERE id IN ($in_clause)", @page_ids)->hashes;
            my %row_map = map { $_->{id} => $_ } @$rows;

            # Reconstruct list in correct order
            for my $id (@page_ids) {
                push @songs, $row_map{$id} if $row_map{$id};
            }
        }

        # Process song data (highlighting, formatting)
        my @final_songs;
        for my $row (@songs) {
            my $id = $row->{id};
            my $is_radio = $row->{location} =~ /^https?:\/\//i;
            my $duration = $row->{duration};
            if ($is_radio && (!$duration)) {
                $duration = undef;
            }

            my $track_number = $row->{track_number};
            $track_number =~ s{/.*}{} if defined $track_number;

            my $song_data = {
                %$row,
                duration => $duration,
                track_number => $track_number,
                is_radio => $is_radio,
            };

            # Highlighting logic
            if ($matches_by_id && exists $matches_by_id->{$id}) {
                my $song_matches = $matches_by_id->{$id};
                for my $field_name (qw(title artist album)) {
                    next unless $song_matches->{$field_name} && keys %{ $song_matches->{$field_name} };

                    my $original_text = $row->{$field_name};
                    my $words_to_highlight_hash = $song_matches->{$field_name};

                    my @parts = split /(\s+)/, $original_text;
                    my @highlighted_parts;
                    for my $part (@parts) {
                        if ($part =~ /^\s*$/) {
                            push @highlighted_parts, $part;
                            next;
                        }
                        my $norm_part = _normalize_for_search($part);

                        # Check for exact/fuzzy match first
                        if (exists $words_to_highlight_hash->{$norm_part}) {
                            my $match_info = $words_to_highlight_hash->{$norm_part};
                            if (ref($match_info) eq 'HASH' && $match_info->{type} eq 'fuzzy') {
                                my $highlighted_word = _highlight_fuzzy_diff($part, $match_info->{term});
                                push @highlighted_parts, $highlighted_word;
                            } else {
                                # Exact match
                                push @highlighted_parts, '<span class="text-cyan-400 neon-text-cyan">' . $part . '</span>';
                            }
                        } else {
                            # Check for substring matches where the term is smaller than the word
                            my $did_highlight = 0;
                            if (exists $words_to_highlight_hash->{'__substrings__'}) {
                                # We can only do precise highlighting if normalization didn't change length
                                # (e.g. punctuation removal breaks 1-to-1 index mapping)
                                if (length($part) == length($norm_part)) {
                                    my @matches;
                                    # Collect all match ranges for all terms
                                    for my $term (@{ $words_to_highlight_hash->{'__substrings__'} }) {
                                        my $pos = index($norm_part, $term);
                                        if ($pos != -1) {
                                            push @matches, [$pos, $pos + length($term)];
                                        }
                                    }

                                    if (@matches) {
                                        $did_highlight = 1;
                                        # Sort matches by start position
                                        @matches = sort { $a->[0] <=> $b->[0] } @matches;

                                        # Determine cut points (boundaries of highlights)
                                        my %points;
                                        $points{0} = 1;
                                        $points{length($part)} = 1;
                                        for my $m (@matches) {
                                            $points{$m->[0]} = 1;
                                            $points{$m->[1]} = 1;
                                        }
                                        my @sorted_points = sort { $a <=> $b } keys %points;

                                        # Build the highlighted string from fragments
                                        my $constructed = '';
                                        for (my $i = 0; $i < @sorted_points - 1; $i++) {
                                            my $start = $sorted_points[$i];
                                            my $end = $sorted_points[$i+1];
                                            my $fragment = substr($part, $start, $end - $start);

                                            # Check if this fragment is inside any match range
                                            my $in_match = 0;
                                            for my $m (@matches) {
                                                if ($start >= $m->[0] && $end <= $m->[1]) {
                                                    $in_match = 1;
                                                    last;
                                                }
                                            }

                                            if ($in_match) {
                                                $constructed .= '<span class="text-cyan-400 neon-text-cyan">' . $fragment . '</span>';
                                            } else {
                                                $constructed .= $fragment;
                                            }
                                        }
                                        push @highlighted_parts, $constructed;
                                    }
                                }

                                # Fallback if no precise matches found or length mismatch
                                if (!$did_highlight) {
                                    for my $term (@{ $words_to_highlight_hash->{'__substrings__'} }) {
                                        if (index($norm_part, $term) != -1) {
                                            push @highlighted_parts, '<span class="text-cyan-400 neon-text-cyan">' . $part . '</span>';
                                            $did_highlight = 1;
                                            last;
                                        }
                                    }
                                }
                            }
                            push @highlighted_parts, $part unless $did_highlight;
                        }
                    }
                    my $highlighted_text = join('', @highlighted_parts);
                    if ($highlighted_text ne $original_text) {
                        $song_data->{$field_name . '_html'} = $highlighted_text;
                    }
                }
            }
            push @final_songs, $song_data;
        }

        return { songs => \@final_songs, total => $total_songs };
    }

    # Build SQL query (Standard path when not preserving order)
    my $where_clause = "1=1";
    my @bind_params;

    if ($initial_song_ids_ref) {
        if (@$initial_song_ids_ref) {
            $where_clause .= " AND id IN (" . join(',', ('?') x @$initial_song_ids_ref) . ")";
            push @bind_params, @$initial_song_ids_ref;
        } else {
            # Filter matched nothing, so result should be empty
            return { songs => [], total => 0 };
        }
    }

    if (defined $ratings_filter_str && length $ratings_filter_str) {
        my @ratings = split /\|/, $ratings_filter_str;
        # Validate ratings are numeric 0-5
        @ratings = grep { /^\d+$/ && $_ >= 0 && $_ <= 5 } @ratings;
        if (@ratings) {
            $where_clause .= " AND (rating IN (" . join(',', ('?') x @ratings) . ")";
            # If 0 is in the filter, also include NULL ratings
            if (grep { $_ == 0 } @ratings) {
                $where_clause .= " OR rating IS NULL";
            }
            $where_clause .= ")";
            push @bind_params, @ratings;
        }
    }

    # Blacklists - only apply if there are patterns to match
    # Using NOT REGEXP can be slow, so we only add these clauses if needed
    if (@BLACKLIST_ARTISTS_MATCHING) {
        for my $regex (@BLACKLIST_ARTISTS_MATCHING) {
            next unless defined $regex && length $regex;
            $where_clause .= " AND artist NOT REGEXP ?";
            push @bind_params, $regex;
        }
    }
    if (@BLACKLIST_GENRES_MATCHING) {
        for my $regex (@BLACKLIST_GENRES_MATCHING) {
            next unless defined $regex && length $regex;
            $where_clause .= " AND genre NOT REGEXP ?";
            push @bind_params, $regex;
        }
    }

    my $order_by = "";
    if (defined $shuffle_param) {
        $order_by = "RANDOM()";
    } elsif (!$disable_sort) {
        my %sort_map = (
            title    => 'title',
            artist   => 'artist',
            album    => 'album',
            genre    => 'genre',
            duration => 'duration',
            rating   => 'rating',
            track_number => 'track_number',
            bitrate  => 'bitrate',
        );
        my $col = $sort_map{$sort_by} // 'artist';
        my $collation = ($col =~ /^(title|artist|album|genre)$/) ? "COLLATE SYNTH_SORT" : "";
        $order_by = "$col $collation " . uc($sort_dir);
        # Secondary sort for stability
        $order_by .= ", artist COLLATE SYNTH_SORT ASC, album COLLATE SYNTH_SORT ASC, track_number ASC, title COLLATE SYNTH_SORT ASC";
    }

    my $total_songs = $sql->db->query("SELECT COUNT(*) FROM songs WHERE $where_clause", @bind_params)->array->[0];

    my $query = "SELECT * FROM songs WHERE $where_clause";
    $query .= " ORDER BY $order_by" if $order_by;

    if (defined $limit && $limit > 0) {
        my $offset = ($page - 1) * $limit;
        $query .= " LIMIT ? OFFSET ?";
        push @bind_params, $limit, $offset;
    }

    my $results = $sql->db->query($query, @bind_params);

    # 5. Prepare song data for response
    my @songs;
    while (my $row = $results->hash) {
        my $id = $row->{id};
        my $is_radio = $row->{location} =~ /^https?:\/\//i;
        my $duration = $row->{duration};
        if ($is_radio && (!$duration)) {
            $duration = undef;
        }

        my $track_number = $row->{track_number};
        $track_number =~ s{/.*}{} if defined $track_number;

        my $song_data = {
            %$row,
            duration => $duration,
            track_number => $track_number,
            is_radio => $is_radio,
        };

        if ($matches_by_id && exists $matches_by_id->{$id}) {
            my $song_matches = $matches_by_id->{$id};
            for my $field_name (qw(title artist album)) {
                next unless $song_matches->{$field_name} && keys %{ $song_matches->{$field_name} };

                my $original_text = $row->{$field_name};
                my $words_to_highlight_hash = $song_matches->{$field_name};

                my @parts = split /(\s+)/, $original_text;
                my @highlighted_parts;
                for my $part (@parts) {
                    if ($part =~ /^\s*$/) {
                        push @highlighted_parts, $part;
                        next;
                    }
                    my $norm_part = _normalize_for_search($part);
                    if (exists $words_to_highlight_hash->{$norm_part}) {
                        my $match_info = $words_to_highlight_hash->{$norm_part};
                        if (ref($match_info) eq 'HASH' && $match_info->{type} eq 'fuzzy') {
                            my $highlighted_word = _highlight_fuzzy_diff($part, $match_info->{term});
                            push @highlighted_parts, $highlighted_word;
                        } else {
                            # Exact match: highlight it in cyan
                            push @highlighted_parts, '<span class="text-cyan-400 neon-text-cyan">' . $part . '</span>';
                        }
                    } else {
                        # Check for substring matches where the term is smaller than the word
                        my $did_highlight = 0;
                        if (exists $words_to_highlight_hash->{'__substrings__'}) {
                            for my $term (@{ $words_to_highlight_hash->{'__substrings__'} }) {
                                if (index($norm_part, $term) != -1) {
                                    push @highlighted_parts, '<span class="text-cyan-400 neon-text-cyan">' . $part . '</span>';
                                    $did_highlight = 1;
                                    last;
                                }
                            }
                        }
                        push @highlighted_parts, $part unless $did_highlight;
                    }
                }
                my $highlighted_text = join('', @highlighted_parts);
                if ($highlighted_text ne $original_text) {
                    $song_data->{$field_name . '_html'} = $highlighted_text;
                }
            }
        }
        push @songs, $song_data;
    }

    return { songs => \@songs, total => $total_songs };
}

# Determines the initial set of songs to be processed based on playlist/genre filters
sub _get_initial_song_ids_from_context {
    my ($c) = @_;
    my $sql = $c->app->sql;
    my $logic = $c->param('logic') || 'and';
    my $playlists_str = $c->param('playlists');
    my $genres_str = $c->param('genres');
    my $artists_str = $c->param('artists');
    my $albums_str = $c->param('albums');

    my @active_filters;
    push @active_filters, { str => $playlists_str, type => 'playlist' } if $playlists_str;
    push @active_filters, { str => $genres_str,    type => 'genre'    } if $genres_str;
    push @active_filters, { str => $artists_str,   type => 'artist'   } if $artists_str;
    push @active_filters, { str => $albums_str,    type => 'album'    } if $albums_str;

    if (!@active_filters) {
        return undef; # Means all songs
    }

    my $song_ids_ref;
    my $is_first_filter = 1;

    for my $filter (@active_filters) {
        my @current_matches;
        if ($filter->{type} eq 'playlist') {
            my @names = split /\|/, $filter->{str};
            # Filter out empty names to prevent SQL issues
            @names = grep { defined && length } @names;
            next unless @names;
            @current_matches = $sql->db->query(
                "SELECT song_id FROM playlist_songs WHERE playlist_name IN (" . join(',', ('?') x @names) . ")",
                @names
            )->arrays->map(sub { $_->[0] })->each;
        } else {
            my $col = $filter->{type};
            # Validate column name against whitelist
            my %valid_cols = map { $_ => 1 } qw(genre artist album);
            next unless $valid_cols{$col};
            my @vals = split /\|/, $filter->{str};
            # Filter out empty values
            @vals = grep { defined && length } @vals;
            next unless @vals;
            @current_matches = $sql->db->query(
                "SELECT id FROM songs WHERE $col IN (" . join(',', ('?') x @vals) . ")",
                @vals
            )->arrays->map(sub { $_->[0] })->each;
        }

        if ($is_first_filter) {
            $song_ids_ref = { map { $_ => 1 } @current_matches };
            $is_first_filter = 0;
        } else {
            if ($logic eq 'or') {
                # Union: Add all new matches to the set
                $song_ids_ref->{$_} = 1 for @current_matches;
            } else {
                # Intersection (AND): Keep only IDs present in both sets
                my %new_set;
                my %current_map = map { $_ => 1 } @current_matches;
                for my $id (keys %$song_ids_ref) {
                    $new_set{$id} = 1 if $current_map{$id};
                }
                $song_ids_ref = \%new_set;
            }
        }
    }

    return [keys %$song_ids_ref];
}

# Ranks search results based on query terms and scoring logic
sub rank_search_results {
    my ($query, $normalized_query_terms, $results_iterator) = @_;
    my @matching_songs;
    my %matches_by_id;

    while (my $row = $results_iterator->hash) {
        my $id = $row->{id};

        my $title_norm  = _normalize_for_search($row->{title} // '');
        my $artist_norm = _normalize_for_search($row->{artist} // '');
        my $album_norm  = _normalize_for_search($row->{album} // '');

        my $total_score = 0;
        if ((lc($query) eq 'radio' || lc($query) eq 'stream') && $row->{location} =~ /^https?:\/\//i) {
            $total_score += 1000;
        }
        my $terms_matched = 0;
        my %song_matches;

        TERM: for my $term (@$normalized_query_terms) {
            my $term_score = 0;
            my $found_match_for_term = 0;
            my $is_exact_word_match_for_term = 0;

            # --- Pass 1: Exact whole word matches (highest preference) ---
            if ($title_norm =~ /\b\Q$term\E\b/) {
                $term_score += 15;
                $song_matches{title}{$term} = { type => 'exact' };
                if (index($title_norm, $term) == 0) { $term_score += 3; } # Start of title bonus
                $is_exact_word_match_for_term = 1;
            }
            if ($artist_norm =~ /\b\Q$term\E\b/) {
                $term_score += 8;
                $song_matches{artist}{$term} = { type => 'exact' };
                $is_exact_word_match_for_term = 1;
            }
            if ($album_norm =~ /\b\Q$term\E\b/) {
                $term_score += 4;
                $song_matches{album}{$term} = { type => 'exact' };
                $is_exact_word_match_for_term = 1;
            }

            if ($is_exact_word_match_for_term) {
                $found_match_for_term = 1;
            }

            # --- Pass 1.5: Acronym matches ---
            if (!$found_match_for_term) {
                my @title_words = split /\s+/, $title_norm;
                my $initials = join('', map { substr($_, 0, 1) } @title_words);
                if ($initials eq $term) {
                    $term_score += 10;
                    $found_match_for_term = 1;
                    # Mark each word as an exact match so they all get highlighted
                    for my $word (@title_words) {
                        next unless length($word) > 0;
                        $song_matches{title}{$word} = { type => 'exact' };
                    }
                }
            }

            # --- Pass 2: Fuzzy word matches (medium preference) ---
            if (!$is_exact_word_match_for_term && length($term) >= 4) {
                my $found_fuzzy_match = 0;
                # Check title
                for my $word (split /\s+/, $title_norm) {
                    next if abs(length($word) - length($term)) > 2;
                    my $dist = _levenshtein_distance($word, $term);
                    if ($dist <= 2) {
                        if (!exists($song_matches{title}{$word}) || $song_matches{title}{$word}{type} ne 'exact') {
                            $song_matches{title}{$word} = { type => 'fuzzy', term => $term };
                        }
                        $term_score += ($dist == 1 ? 7 : 3);
                        $found_fuzzy_match = 1;
                        last;
                    }
                }
                # Check artist
                for my $word (split /\s+/, $artist_norm) {
                    next if abs(length($word) - length($term)) > 2;
                    my $dist = _levenshtein_distance($word, $term);
                    if ($dist <= 2) {
                        if (!exists($song_matches{artist}{$word}) || $song_matches{artist}{$word}{type} ne 'exact') {
                            $song_matches{artist}{$word} = { type => 'fuzzy', term => $term };
                        }
                        $term_score += ($dist == 1 ? 3 : 1);
                        $found_fuzzy_match = 1;
                        last;
                    }
                }
                # Check album
                for my $word (split /\s+/, $album_norm) {
                    next if abs(length($word) - length($term)) > 2;
                    my $dist = _levenshtein_distance($word, $term);
                    if ($dist <= 2) {
                        if (!exists($song_matches{album}{$word}) || $song_matches{album}{$word}{type} ne 'exact') {
                            $song_matches{album}{$word} = { type => 'fuzzy', term => $term };
                        }
                        $term_score += ($dist == 1 ? 1 : 0.5);
                        $found_fuzzy_match = 1;
                        last;
                    }
                }
                if ($found_fuzzy_match) {
                    $found_match_for_term = 1;
                }
            }

            # --- Pass 3: Substring matches (lowest preference) ---
            if (!$found_match_for_term) {
                if (index($title_norm, $term) != -1) {
                    $term_score += 5;
                    $found_match_for_term = 1;
                    $song_matches{title}{'__substrings__'} ||= [];
                    push @{$song_matches{title}{'__substrings__'}}, $term unless grep { $_ eq $term } @{$song_matches{title}{'__substrings__'}};
                }
                if (index($artist_norm, $term) != -1) {
                    $term_score += 2;
                    $found_match_for_term = 1;
                    $song_matches{artist}{'__substrings__'} ||= [];
                    push @{$song_matches{artist}{'__substrings__'}}, $term unless grep { $_ eq $term } @{$song_matches{artist}{'__substrings__'}};
                }
                if (index($album_norm, $term) != -1) {
                    $term_score += 1;
                    $found_match_for_term = 1;
                    $song_matches{album}{'__substrings__'} ||= [];
                    push @{$song_matches{album}{'__substrings__'}}, $term unless grep { $_ eq $term } @{$song_matches{album}{'__substrings__'}};
                }
            }

            if ($found_match_for_term) {
                $terms_matched++;
                $total_score += $term_score;
            }
        }

        if ($terms_matched > 0) {
            my $full_text_norm = "$title_norm $artist_norm $album_norm";
            if (index($full_text_norm, _normalize_for_search($query)) != -1) {
                $total_score += 20; # Significant bonus for matching the phrase
            }

            # Penalty for not matching all terms to keep them at the bottom
            if ($terms_matched < @$normalized_query_terms) {
                $total_score = $total_score / (@$normalized_query_terms * 2);
            }

            push @matching_songs, {
                id     => $id,
                score  => $total_score,
                artist => $row->{artist} // '',
                album  => $row->{album} // '',
                title  => $row->{title} // '',
            };
            $matches_by_id{$id} = \%song_matches if keys %song_matches;
        }
    }

    my $clean_sub = sub {
        my $s = shift // '';
        $s =~ s/[àáâãäåāăą]/a/g;
        $s =~ s/[èéêëēĕėęě]/e/g;
        $s =~ s/[ìíîïĩīĭįı]/i/g;
        $s =~ s/[òóôõöōŏő]/o/g;
        $s =~ s/[ùúûüũūŭůűų]/u/g;
        $s =~ s/[çćĉċč]/c/g;
        $s =~ s/ñ/n/g;
        $s =~ s/ý/y/g;
        $s =~ s/ż/z/g;
        $s =~ s/["'«»„“]//g;
        $s =~ s/[^a-z0-9\s]//g;
        return lc($s);
    };

    @matching_songs = sort {
        $b->{score} <=> $a->{score}
        || _natural_compare($clean_sub->($a->{artist}), $clean_sub->($b->{artist}))
        || _natural_compare($clean_sub->($a->{album}),  $clean_sub->($b->{album}))
        || _natural_compare($clean_sub->($a->{title}),  $clean_sub->($b->{title}))
    } @matching_songs;

    my @matching_song_ids = map { $_->{id} } @matching_songs;
    return (\@matching_song_ids, \%matches_by_id);
}

# Encapsulates the search logic: normalization, SQL filtering, and ranking
sub search_songs {
    my ($c, $query) = @_;
    return { songs => [], total => 0 } unless $query && length($query) > 0;

    my @query_terms = split /\s+/, $query;
    my @normalized_query_terms = grep { $_ } map { split /\s+/, _normalize_for_search($_) } @query_terms;
    return { songs => [], total => 0 } unless @normalized_query_terms;

    # 1. Determine initial song list based on context (playlists, genres, etc.)
    my $initial_song_ids = _get_initial_song_ids_from_context($c);

    # 2. Filter by search query using SQL first for performance
    my $where = "1=1";
    my @bind;
    my @term_clauses;
    for my $term (@normalized_query_terms) {
        if (length($term) >= 4) {
            # For fuzzy-eligible terms, we broaden the SQL filter to catch potential typos.
            # We use a 2-character prefix to be inclusive while maintaining performance, relying on rank_search_results to filter.
            my $prefix = substr($term, 0, 2);
            push @term_clauses, "(title LIKE ? OR artist LIKE ? OR album LIKE ? OR title LIKE ? OR artist LIKE ? OR album LIKE ?)";
            push @bind, "%$term%", "%$term%", "%$term%", "$prefix%", "$prefix%", "$prefix%";
        } else {
            push @term_clauses, "(title LIKE ? OR artist LIKE ? OR album LIKE ?)";
            push @bind, "%$term%", "%$term%", "%$term%";
        }
    }
    if (@term_clauses) {
        $where .= " AND (" . join(" OR ", @term_clauses) . ")";
    }
    if ($initial_song_ids) {
        if (@$initial_song_ids) {
            $where .= " AND id IN (" . join(',', ('?') x @$initial_song_ids) . ")";
            push @bind, @$initial_song_ids;
        } else {
            return { songs => [], total => 0 };
        }
    }

    my $results = $c->app->sql->db->query("SELECT * FROM songs WHERE $where", @bind);

    # 3. Rank results and get match metadata for highlighting
    my ($matching_song_ids_ref, $matches_by_id) = rank_search_results($query, \@normalized_query_terms, $results);

    # 4. Use _get_processed_songs for genre/rating filters, sorting, and pagination
    # If a manual sort is requested, we don't preserve the relevance order.
    my $has_manual_sort = $c->param('sort') ? 1 : 0;

    return _get_processed_songs($c, $matching_song_ids_ref, {
        disable_sort   => !$has_manual_sort,
        matches        => $matches_by_id,
        preserve_order => !$has_manual_sort
    });
}

# Helper to highlight the difference between two words for fuzzy search results.
sub _highlight_fuzzy_diff {
    my ($word_from_db, $search_term_norm) = @_;

    my $word_from_db_norm = _normalize_for_search($word_from_db);
    my @db_chars_orig = split //, $word_from_db;
    my @db_chars_norm = split //, $word_from_db_norm;
    my @term_chars_norm = split //, $search_term_norm;
    my $highlight_tag_open = '<mark style="background-color: transparent; color: #ff8c00; text-shadow: 0 0 5px #ff8c00;">';
    my $highlight_tag_close = '</mark>';
    my $cyan_tag_open = '<span class="text-cyan-400 neon-text-cyan">';
    my $cyan_tag_close = '</span>';


    # This check is crucial for cases where normalization changes length (e.g., removing punctuation)
    # We can only reliably map indices if original and normalized versions have same length.
    if (@db_chars_orig != @db_chars_norm) {
        # Fallback: Highlight whole word as fuzzy (Cyan with Orange content) to maintain consistency
        return "$cyan_tag_open$highlight_tag_open$word_from_db$highlight_tag_close$cyan_tag_close";
    }

    # Case 1: Substitution or Transposition (same length)
    if (@db_chars_norm == @term_chars_norm) {
        my @diffs;
        for (my $i = 0; $i < @db_chars_norm; $i++) {
            push @diffs, $i if $db_chars_norm[$i] ne $term_chars_norm[$i];
        }

        # Substitution (1 char diff) or Transposition (2 chars diff)
        if (@diffs == 1 || @diffs == 2) {
            my @parts = @db_chars_orig;
            $parts[$_] = "$highlight_tag_open$parts[$_]$highlight_tag_close" for @diffs;
            return "$cyan_tag_open" . join('', @parts) . "$cyan_tag_close";
        }
    }
    # Case 2: Insertion (db word is 1 char longer)
    elsif (@db_chars_norm == @term_chars_norm + 1) {
        for (my $i = 0; $i < @db_chars_norm; $i++) {
            my @temp_db_chars = @db_chars_norm;
            splice(@temp_db_chars, $i, 1);
            if (join('', @temp_db_chars) eq $search_term_norm) {
                my @parts = @db_chars_orig;
                $parts[$i] = "$highlight_tag_open$parts[$i]$highlight_tag_close";
                return "$cyan_tag_open" . join('', @parts) . "$cyan_tag_close";
            }
        }
    }
    # Case 3: Deletion (db word is 1 char shorter). The search term has an extra letter.
    # The Levenshtein check already confirms it's a match. All of the DB word is part of the
    # search term, so it should be all cyan.
    elsif (@db_chars_norm + 1 == @term_chars_norm) {
        return "$cyan_tag_open$word_from_db$cyan_tag_close";
    }

    # Fallback for complex cases (e.g., transposition) or if no single diff was found (shouldn't happen with Levenshtein=1)
    return "$cyan_tag_open$highlight_tag_open$word_from_db$highlight_tag_close$cyan_tag_close";
}

# Returns the minimum of three numbers.
sub _min3 {
    my ($a, $b, $c) = @_;
    return $a < $b ? ($a < $c ? $a : $c) : ($b < $c ? $b : $c);
}

# Calculates Levenshtein distance between two strings.
sub _levenshtein_distance {
    my ($s1, $s2) = @_;
    my @s1_chars = split //, $s1;
    my @s2_chars = split //, $s2;
    my $len1 = @s1_chars;
    my $len2 = @s2_chars;
    return $len2 if !$len1;
    return $len1 if !$len2;
    my @v0 = (0..$len2);
    my @v1;

    for my $i (0..$len1-1) {
        $v1[0] = $i + 1;
        for my $j (0..$len2-1) {
            my $cost = ($s1_chars[$i] eq $s2_chars[$j]) ? 0 : 1;
            $v1[$j+1] = _min3($v1[$j] + 1, $v0[$j+1] + 1, $v0[$j] + $cost);
        }
        @v0 = @v1;
    }
    return $v0[$len2];
}

# Normalizes a string for searching (lowercase, un-accent, remove special chars).
sub _normalize_for_search {
    my ($str) = @_;
    return '' unless defined $str;
    my $s = lc $str;
    # Diacritics from https://en.wikipedia.org/wiki/Diacritic
    $s =~ s/[àáâãäåāăą]/a/g;
    $s =~ s/[èéêëēĕėęě]/e/g;
    $s =~ s/[ìíîïĩīĭįı]/i/g;
    $s =~ s/[òóôõöōŏő]/o/g;
    $s =~ s/[ùúûüũūŭůűų]/u/g;
    $s =~ s/[çćĉċč]/c/g;
    $s =~ s/ñ/n/g;
    $s =~ s/ý/y/g;
    $s =~ s/ż/z/g;
    # Non-alphanumeric
    $s =~ s/[^a-z0-9\s]//g;
    return $s;
}

