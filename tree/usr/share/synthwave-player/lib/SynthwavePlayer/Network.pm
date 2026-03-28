package SynthwavePlayer::Network;

use strict;
use warnings;
use Exporter 'import';
use Net::UPnP::ControlPoint;
use Net::UPnP::GW::Gateway;
use IO::Socket::INET;
use Try::Tiny;
use URI::Escape qw(uri_escape);

our @EXPORT_OK = qw(is_private_ip setup_upnp check_port_is_available remove_from_ip_cache compile_regex check_rate_limit _apply_rate_limit check_admin process_login get_login_lockout process_logout);

# Cache for private IP check
my %IP_CACHE;
my %COMPILED_REGEX_CACHE;

# Rate limiting state
my %IP_LIMITS;
my %GLOBAL_LIMITS = ( count => 0, last_reset => time() );
my $LAST_CLEANUP = 0;

# Admin login attempts state
my %LOGIN_ATTEMPTS;
my $LAST_LOGIN_CLEANUP = 0;

sub check_admin {
    my ($c, $admin_password) = @_;
    return 1 if $c->session('admin');
    my $ip = $c->tx->remote_address;
    # Grant admin privileges to localhost ONLY if no admin password is set yet (initial setup)
    if ($ip eq '127.0.0.1' || $ip eq '::1' || $ip eq 'localhost') {
        return 1 if !$admin_password || $admin_password eq '';
    }
    return 0;
}

sub get_login_lockout {
    my ($ip) = @_;
    my $now = time();
    if (exists $LOGIN_ATTEMPTS{$ip} && $LOGIN_ATTEMPTS{$ip}{lockout_until} > $now) {
        return $LOGIN_ATTEMPTS{$ip}{lockout_until};
    }
    return 0;
}

sub process_login {
    my ($c, $password, $admin_password) = @_;
    my $ip = $c->tx->remote_address;
    my $now = time();

    # Initialize or clean up old daily stats
    $LOGIN_ATTEMPTS{$ip} //= { count => 0, daily_count => 0, last_attempt => 0, lockout_until => 0, day_start => $now };

    # Reset daily counter if 24h passed
    if ($now - $LOGIN_ATTEMPTS{$ip}{day_start} > 86400) {
        $LOGIN_ATTEMPTS{$ip}{daily_count} = 0;
        $LOGIN_ATTEMPTS{$ip}{day_start} = $now;
    }

    # Check for active lockout
    if ($LOGIN_ATTEMPTS{$ip}{lockout_until} > $now) {
        return (0, 'Too many failed attempts. Access restricted.', $LOGIN_ATTEMPTS{$ip}{lockout_until});
    }

    if (defined $password && $password eq $admin_password) {
        $c->session(admin => 1);
        $c->session(expiration => 315360000);
        delete $LOGIN_ATTEMPTS{$ip};
        return (1, 'Login successful.', 0);
    } else {
        $LOGIN_ATTEMPTS{$ip}{count}++;
        $LOGIN_ATTEMPTS{$ip}{daily_count}++;
        $LOGIN_ATTEMPTS{$ip}{last_attempt} = $now;

        # Apply lockout logic
        if ($LOGIN_ATTEMPTS{$ip}{daily_count} >= 40) {
            $LOGIN_ATTEMPTS{$ip}{lockout_until} = $now + (7 * 86400); # 1 week
        } elsif ($LOGIN_ATTEMPTS{$ip}{daily_count} >= 20) {
            $LOGIN_ATTEMPTS{$ip}{lockout_until} = $now + 86400; # 1 day
        } elsif ($LOGIN_ATTEMPTS{$ip}{count} >= 10) {
            $LOGIN_ATTEMPTS{$ip}{lockout_until} = $now + 3600; # 1 hour
            $LOGIN_ATTEMPTS{$ip}{count} = 0; # Reset short-term counter after applying lockout
        }
        return (0, 'Authentication failed. Please check your credentials.', $LOGIN_ATTEMPTS{$ip}{lockout_until} || 0);
    }
}

sub process_logout {
    my ($c) = @_;
    # Completely clear the session data and expire the cookie
    $c->session(admin => 0);
    delete $c->session->{admin};
    $c->session(expires => 1);
}

sub _apply_rate_limit {
    my ($c) = @_;
    unless ($c->rate_limiter) {
        my $msg = $c->stash('rate_limit_error') || "Rate limit exceeded";
        $c->res->headers->header('X-Error-Notification', uri_escape($msg));
        $c->render(json => { error => $msg }, status => 429);
        return 0;
    }
    return 1;
}

sub check_rate_limit {
    my ($ip, $address, $log, $config) = @_;

    # Do not rate limit localhost or machines on the same local network
    if (is_private_ip($address, $config->{private_networks}, $log)) {
        return 1;
    }

    my $time = time();

    # Periodic cleanup of the entire IP limits hash (every 5 minutes)
    if ($time - $LAST_CLEANUP > 300) {
        for my $stored_ip (keys %IP_LIMITS) {
            if ($IP_LIMITS{$stored_ip}{last_reset} < $time - $config->{rate_limit_window}) {
                delete $IP_LIMITS{$stored_ip};
            }
        }
        $LAST_CLEANUP = $time;
    }

    # Periodic cleanup of login attempts (every 30 minutes)
    if ($time - $LAST_LOGIN_CLEANUP > 1800) {
        for my $stored_ip (keys %LOGIN_ATTEMPTS) {
            # Remove entries older than 24 hours or with expired lockouts
            if (exists $LOGIN_ATTEMPTS{$stored_ip}) {
                my $entry = $LOGIN_ATTEMPTS{$stored_ip};
                if ($entry->{lockout_until} && $entry->{lockout_until} < $time) {
                    # Lockout expired, check if we should keep the entry
                    if ($entry->{daily_count} == 0 || ($time - $entry->{day_start}) > 86400) {
                        delete $LOGIN_ATTEMPTS{$stored_ip};
                    }
                }
            }
        }
        $LAST_LOGIN_CLEANUP = $time;
    }

    # Reset global counter if window has passed
    if ($GLOBAL_LIMITS{last_reset} < $time - $config->{global_rate_limit_window}) {
        $GLOBAL_LIMITS{count} = 0;
        $GLOBAL_LIMITS{last_reset} = $time;
    }

    # Check global limit first
    if ($GLOBAL_LIMITS{count} >= $config->{global_rate_limit_requests}) {
        $log->warn("Global rate limit exceeded") if $log;
        return (0, "Global rate limit exceeded. Max " . $config->{global_rate_limit_requests} . " requests per " . $config->{global_rate_limit_window} . " seconds allowed.");
    }

    # Initialize limit tracking for this IP if needed
    unless (exists $IP_LIMITS{$ip}) {
        # Check if we've reached the maximum number of simultaneous IPs
        if (scalar(keys %IP_LIMITS) >= $config->{max_simultaneous_ips}) {
            # Try to free space by removing expired entries immediately
            for my $stored_ip (keys %IP_LIMITS) {
                if ($IP_LIMITS{$stored_ip}{last_reset} < $time - $config->{rate_limit_window}) {
                    delete $IP_LIMITS{$stored_ip};
                }
            }

            if (scalar(keys %IP_LIMITS) >= $config->{max_simultaneous_ips}) {
                $log->warn("Maximum simultaneous IPs limit reached") if $log;
                return (0, "The server is currently at maximum capacity. Please try again later.");
            }
        }
        $IP_LIMITS{$ip} = {
            count => 0,
            last_reset => $time
        };
    }

    # Reset IP counter if window has passed
    if ($IP_LIMITS{$ip}{last_reset} < $time - $config->{rate_limit_window}) {
        $IP_LIMITS{$ip}{count} = 0;
        $IP_LIMITS{$ip}{last_reset} = $time;
    }

    # Check if IP limit exceeded
    if ($IP_LIMITS{$ip}{count} >= $config->{rate_limit_requests}) {
        $log->warn("IP rate limit exceeded for $ip") if $log;
        return (0, "Your IP has been rate-limited for security reasons / to avoid bots. Please try again in a moment.");
    }

    # Increment counters
    $IP_LIMITS{$ip}{count}++;
    $GLOBAL_LIMITS{count}++;

    return 1;
}

sub compile_regex {
    my ($pattern_str) = @_;
    return $COMPILED_REGEX_CACHE{$pattern_str} if exists $COMPILED_REGEX_CACHE{$pattern_str};

    my $pattern;
    try {
        if ($pattern_str =~ m{^(.+)/([a-z]*)$}) {
            my ($p, $f) = ($1, $2);
            $pattern = eval "qr{$p}$f";
        } else {
            $pattern = qr/$pattern_str/;
        }
        die "Invalid regex from eval" unless $pattern;
    } catch {
        return $COMPILED_REGEX_CACHE{$pattern_str} = undef;
    };
    return $COMPILED_REGEX_CACHE{$pattern_str} = $pattern;
}

sub is_private_ip {
    my ($ip, $private_networks_ref, $logger) = @_;
    return $IP_CACHE{$ip} if exists $IP_CACHE{$ip};

    my $is_private = 0;

    for my $pattern_str (@$private_networks_ref) {
        my $pattern = compile_regex($pattern_str);
        unless ($pattern) {
            $logger->error("Invalid regex in PRIVATE_NETWORKS: '$pattern_str'.") if $logger;
            next;
        }

        if ($ip =~ $pattern) {
            $is_private = 1;
            last;
        }
    }

    return $IP_CACHE{$ip} = $is_private;
}

sub remove_from_ip_cache {
    my ($ip) = @_;
    delete $IP_CACHE{$ip};
}

sub check_port_is_available {
    my ($port, $logger, $is_dev) = @_;

    # In a multi-worker environment (e.g., Hypnotoad), the master process
    # handles port binding. Attempting to bind here can cause workers to
    # incorrectly report the port as unavailable. We rely on the server's
    # own binding logic to handle conflicts.
    return 1;
}

sub setup_upnp {
    my ($port, $logger, $quiet) = @_;

    return unless $port;
    $logger->info("Attempting to configure port forwarding via UPnP...") unless $quiet;

    my $error_msg_out;

    try {
        my $upnp = Net::UPnP::ControlPoint->new;
        my @devices = $upnp->search(st => 'upnp:rootdevice', mx => 10);

        my $sock = IO::Socket::INET->new(PeerAddr => '8.8.8.8', PeerPort => 53, Timeout => 2);
        my $local_ip = $sock ? $sock->sockhost : undef;
        $sock->close if $sock;

        unless($local_ip) {
            $logger->warn("Could not determine local IP address for UPnP, skipping port forwarding.");
            return;
        }
        $logger->info("Local IP for UPnP determined: $local_ip") unless $quiet;

        my $gateway_found = 0;
        foreach my $device (@devices) {
            my $device_type = $device->getdevicetype();
            if ($device_type =~ /InternetGatewayDevice/) {
                $gateway_found = 1;
                $logger->info("Found UPnP-capable gateway: " . $device->getfriendlyname()) unless $quiet;

                my $gateway = Net::UPnP::GW::Gateway->new();
                $gateway->setdevice($device);

                # Add port mapping
                my $result = $gateway->addportmapping(
                    NewRemoteHost           => '',
                    NewExternalPort         => $port,
                    NewProtocol             => 'TCP',
                    NewInternalPort         => $port,
                    NewInternalClient       => $local_ip,
                    NewEnabled              => 1,
                    NewPortMappingDescription => "Synthwave Music Player",
                    NewLeaseDuration        => 0 # Infinite
                );

                if ($result) {
                    $logger->info("SUCCESS! Port forwarding enabled via UPnP.") unless $quiet;
                    $logger->info("Server should be accessible from the Internet on port $port.") unless $quiet;
                } else {
                    my $error_str = $gateway->getlasterrorstr();
                    $logger->error("UPnP port forwarding failed. Reason: " . $error_str);
                    $logger->warn("You may need to manually forward port $port on your router.");
                    $error_msg_out = "UPnP port forwarding failed. Reason: $error_str. You may need to manually forward port $port on your router to share your music online.";
                }
                last;
            }
        }

        unless ($gateway_found) {
            unless ($quiet) {
                $logger->warn("-----------------------------------------------------------------");
                $logger->warn("---       UPnP GATEWAY NOT FOUND                            ---");
                $logger->warn("---                                                         ---");
                $logger->warn("--- No UPnP-enabled gateway was found on your network.      ---");
                $logger->warn("--- Your music server will only be available locally.         ---");
                $logger->warn("---                                                         ---");
                $logger->warn("--- To share your music online with friends, you may need   ---");
                $logger->warn("--- to manually forward port $port (TCP) on your router.      ---");
                $logger->warn("-----------------------------------------------------------------");
            }
            $error_msg_out = "No UPnP-enabled gateway was found on your network. To share your music online, you may need to manually forward port $port (TCP) on your router.";
        }

    } catch {
        my $error_msg = (split /\n/, $_)[0];
        $logger->error("An error occurred during UPnP setup: $error_msg");
        $logger->warn("UPnP discovery failed. Server will likely only be available locally.");
        $error_msg_out = "An error occurred during UPnP setup: $error_msg. UPnP discovery failed. Server will likely only be available locally.";
    };

    return $error_msg_out;
}

1;
