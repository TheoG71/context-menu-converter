# The Nautilus extension is loaded by nautilus-python from %%{_datadir}, not
# imported by the system interpreter, so it must not be byte-compiled (the
# resulting __pycache__ would be an unpackaged file and fail the build).
%undefine __brp_python_bytecompile

Name:           context-menu-converter
Version:        1.0.0
Release:        1%{?dist}
Summary:        Right-click file conversion for Linux file managers

License:        MIT
URL:            https://github.com/TheoG71/context-menu-converter
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz#/%{name}-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  make

Requires:       ImageMagick
Recommends:     libreoffice-core
Recommends:     nautilus-python
Recommends:     libnotify
Suggests:       zenity

%description
Adds a "Convert" entry to the file manager context menu: right-click one or
more images and convert them to PNG, JPG, WEBP or AVIF through ImageMagick, or
right-click office documents and convert them to PDF through LibreOffice. The
converted file is written next to the original, which is kept, and an existing
file is never overwritten.

This package ships the system-wide entries for Nautilus (GNOME), Dolphin (KDE)
and Nemo (Cinnamon), plus the file-convert command-line tool. Thunar and Caja
store their menu entries in per-user files with no system-wide drop-in
location; users of those file managers run install.sh from the source tree.

%prep
%autosetup

%build
# Nothing to build: the project is shell and a generated set of menu entries.

%install
%make_install PREFIX=%{_prefix}

%check
./tests/smoke.sh

%files
%license LICENSE
%doc README.md CHANGELOG.md
%{_bindir}/file-convert
%{_mandir}/man1/file-convert.1*
%{_datadir}/nautilus-python/extensions/file-convert.py
%{_datadir}/kio/servicemenus/file-convert-*.desktop
%{_datadir}/nemo/actions/file-convert-*.nemo_action

%changelog
* Fri Sep 04 2026 Theo <theo.gus@live.fr> - 1.0.0-1
- First release.
