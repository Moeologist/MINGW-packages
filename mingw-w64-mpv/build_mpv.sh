SCRIPT_ROOT=$(dirname $(realpath "$0"))

cd "$SCRIPT_ROOT" || exit 1

for i in ffmpeg mpv vapoursynth libva
do
    # pacman -Q ${MINGW_PACKAGE_PREFIX}-$i && pacman -Rsc --noconfirm ${MINGW_PACKAGE_PREFIX}-$i
    pacman -Q ${MINGW_PACKAGE_PREFIX}-$i && pacman -R --noconfirm ${MINGW_PACKAGE_PREFIX}-$i
done

# PKGS=(srt x265 freetype spirv-cross vid.stab libopenmpt mujs opencl-icd rubberband svt-hevc vulkan-loader xvidcore openal fontconfig shaderc harfbuzz lcms2 openal speex libwebp)
# PKGS=(srt x265 freetype spirv-cross vid.stab opencl-icd rubberband svt-hevc vulkan-headers vulkan-loader xvidcore fontconfig shaderc harfbuzz lcms2 speex libwebp)
PKGS=(libplacebo)

for i in "${PKGS[@]}"
do
    cd $SCRIPT_ROOT/../mingw-w64-$i ||exit 1
    pacman -Q ${MINGW_PACKAGE_PREFIX}-$i && pacman -Rc --noconfirm ${MINGW_PACKAGE_PREFIX}-$i
    rm -f ${MINGW_PACKAGE_PREFIX}-$i*.pkg.tar.*
    makepkg-mingw -Csfi --skippgpcheck --noconfirm
    pacman -Q ${MINGW_PACKAGE_PREFIX}-$i || exit 1
done

cd "$SCRIPT_ROOT" || exit 1
curl -sOL https://gitlab.com/shinchiro/angle/-/archive/main/angle-main.zip?path=include||exit 1
unzip -u angle-main.zip
rm -rf $MINGW_PREFIX/include/EGL
mv -T angle-main-include/include/EGL $MINGW_PREFIX/include/EGL
rm -rf ./angle-main-include

rev=R70
if [[ ${MINGW_PACKAGE_PREFIX} == *-x86_64 ]];then
    curl -sOL "https://github.com/vapoursynth/vapoursynth/releases/download/${rev}/VapourSynth64-Portable-${rev}.zip"||exit 1
    bit=64
else
    curl -sOL "https://github.com/vapoursynth/vapoursynth/releases/download/${rev}/VapourSynth32-Portable-${rev}.zip"||exit 1
    bit=32
    dlltool_args=-U
fi

# 7z x -y -o./vs VapourSynth${bit}-Portable-${rev}.7z
unzip -d ./vs VapourSynth${bit}-Portable-${rev}.zip

cd ./vs || return

cp sdk/include/vapoursynth/* ../

def() {
    gendef $2 - "$1.dll" | sed -r -e 's|^_||' -e 's|@[1-9]+$||' > "$1.def"
}

def VSScript
def VapourSynth

/mingw64/bin/dlltool -d VSScript.def -y libvsscript.a ${dlltool_args}
/mingw64/bin/dlltool -d VapourSynth.def -y libvapoursynth.a ${dlltool_args}

mv libvsscript.a ../
mv libvapoursynth.a ../

cd "$SCRIPT_ROOT" || exit
rm -f vapoursynth*.pc
cp vapoursynth-script.pc.in vapoursynth-script.pc
cp vapoursynth.pc.in vapoursynth.pc
sed -ie "s/@MINGW_INSTALL_PREFIX@/\\${MINGW_PREFIX}/g" vapoursynth*.pc
sed -ie "s/@PC_VERSION@/${rev:1}/g" vapoursynth*.pc

mv ./*.a "${MINGW_PREFIX}/lib/"
mv ./*.pc "${MINGW_PREFIX}/lib/pkgconfig"
mkdir -p "${MINGW_PREFIX}/include/vapoursynth/"
mv ./*.h "${MINGW_PREFIX}/include/vapoursynth/"

rm -rf ./vs ./*.pce ./*.7z

cd $SCRIPT_ROOT/../mingw-w64-ffmpeg
makepkg-mingw -Csfi --skippgpcheck --noconfirm
pacman -Q ${MINGW_PACKAGE_PREFIX}-ffmpeg || exit 1

cd pkg/${MINGW_PACKAGE_PREFIX}-ffmpeg${MINGW_PREFIX}/bin

def_without_head() {
    gendef - "$1.dll" | sed -r -e 's|^_||' -e 's|@[1-9]+$||' -e 's|;.*||' -e 's/(LIBRARY|EXPORTS).*//' -e '/^\s*$/d'
}

echo -n> ffmpeg.def
for i in *.dll;do
    def_without_head "${i%.*}" >> ffmpeg.def
done

mv ffmpeg.def $SCRIPT_ROOT/../mingw-w64-mpv/
cd $SCRIPT_ROOT/../mingw-w64-mpv || exit 1
makepkg-mingw -Csfi --skippgpcheck --noconfirm
