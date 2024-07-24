Name:       harbour-skruuvi

Summary:    Reader for Ruuvi sensors
Version:    1.3.0
Release:    1
License:    GPLv3
URL:        https://github.com/miikasda/harbour-skruuvi
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   pyotherside-qml-plugin-python3-qt5
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5DBus)
BuildRequires:  pkgconfig(Qt5Sql)
BuildRequires:  desktop-file-utils

%description
Skruuvi is a powerful application designed for Sailfish OS that allows you
to effortlessly read and plot history data from RuuviTags. With Skruuvi,
you can easily access and analyze sensor information from your RuuviTag
devices right from your Sailfish OS smartphone.

Note:
Skruuvi is an unofficial application and is not developed or maintained by
Ruuvi. It is created by independent developers who are passionate about
enabling RuuviTag users to maximize their sensor capabilities on Sailfish OS.
For any official RuuviTag support, firmware updates, or inquiries, please
refer to the official Ruuvi website or consult the Ruuvi community forums.


# This section includes metadata for SailfishOS:Chum, see
# https://github.com/sailfishos-chum/main/blob/main/Metadata.md
%if 0%{?_chum}
Title: Skruuvi
Type: desktop-application
DeveloperName: Miika Malin
Categories:
 - Utility
Custom:
  Repo: https://github.com/miikasda/harbour-skruuvi
PackageIcon: https://github.com/miikasda/harbour-skruuvi/raw/main/icons/256x256/harbour-skruuvi.png
Screenshots:
 - https://github.com/miikasda/harbour-skruuvi/raw/main/screenshots/select_device.png
 - https://github.com/miikasda/harbour-skruuvi/raw/main/screenshots/fetch_data.png
 - https://github.com/miikasda/harbour-skruuvi/raw/main/screenshots/plot_data.png
Links:
  Homepage: https://github.com/miikasda/harbour-skruuvi
  Bugtracker: https://github.com/miikasda/harbour-skruuvi/issues
  Donation: https://github.com/sponsors/miikasda
%endif


%prep
%setup -q -n %{name}-%{version}

%build

%qmake5 

%make_build


%install
%qmake5_install


desktop-file-install --delete-original         --dir %{buildroot}%{_datadir}/applications                %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png

# This block is needed for Opal not to provide anything which is not allowed in harbour
# >> macros
%define __provides_exclude_from ^%{_datadir}/.*$
# << macros
