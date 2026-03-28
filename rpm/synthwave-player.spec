Name:           synthwave-player
Version:        %{tag_version}
Release:        1%{?dist}
Summary:        Launcher for the Synthwave Player web interface

License:        GPL-3.0-or-later
URL:            https://github.com/Elive/synthwave-player
Source0:        synthwave-player-%{version}.tar.gz

BuildArch:      noarch

Requires:       synthwave-player-server = %{version}-%{release}
Recommends:     (google-chrome-stable or chromium or firefox), zenity, nc

%description
This package provides a desktop launcher to easily open the Synthwave Player
web interface.

%package -n synthwave-player-server
Summary:        A music player server with a synthwave-themed web interface
Requires:       perl-Mojolicious
Requires:       perl-File-HomeDir
Requires:       perl-XML-LibXML
Requires:       perl-MP3-Tag
Requires:       perl-Digest-SHA
Requires:       perl-URI
Requires:       perl-Net-UPnP
Requires:       perl-Try-Tiny
Requires:       perl-MIME-Base64
Requires:       perl-Linux-Inotify2
Requires:       file

%description -n synthwave-player-server
A music player server with a synthwave-themed web interface. It scans your
music library, and serves a web interface to browse and play your music.
It supports playlists, cover art, and UPnP for remote access.

%prep
%setup -q -n tree

%install
# Main application files
mkdir -p %{buildroot}%{_datadir}/%{name}
cp -r usr/share/%{name}/* %{buildroot}%{_datadir}/%{name}/

# Executables
mkdir -p %{buildroot}%{_bindir}
install -m 755 usr/bin/%{name} %{buildroot}%{_bindir}/%{name}
install -m 755 usr/bin/%{name}-server %{buildroot}%{_bindir}/%{name}-server

# Desktop file
mkdir -p %{buildroot}%{_datadir}/applications
cp usr/share/applications/%{name}.desktop %{buildroot}%{_datadir}/applications/
cp usr/share/applications/%{name}-server.desktop %{buildroot}%{_datadir}/applications/

# Icons
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/scalable/apps
install -m 644 usr/share/%{name}/pixmaps/%{name}.png %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/
install -m 644 usr/share/%{name}/pixmaps/%{name}-rounded.png %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/
install -m 644 usr/share/%{name}/pixmaps/%{name}-server.png %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/
rm -rf %{buildroot}%{_datadir}/%{name}/pixmaps

%files
%{_bindir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/scalable/apps/%{name}.png
%{_datadir}/icons/hicolor/scalable/apps/%{name}-rounded.png

%files -n synthwave-player-server
%{_bindir}/%{name}-server
%{_datadir}/%{name}
%{_datadir}/applications/%{name}-server.desktop
%{_datadir}/icons/hicolor/scalable/apps/%{name}-server.png

%changelog
* Fri Aug 29 2025 Thanatermesis <thanatermesis@elivecd.org> - %{version}-1
- Initial RPM release for version %{version}
