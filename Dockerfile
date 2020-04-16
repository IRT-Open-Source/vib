# base upon Debian Buster
FROM debian:buster

# set correct timezone
ENV TZ=Europe/Berlin

# set generic UTF-8 locale
ENV LC_ALL C.UTF-8

# install necessary packages
RUN apt-get update && apt-get install -y \
 git \
 openjdk-11-jre-headless \
 build-essential \
 yasm \
 wget \
 unzip \
 tar \
 liblzma5 \
 libx264-dev \
 libx265-dev \
 libva-dev \
 librsvg2-dev \
 && rm -rf /var/lib/apt/lists/*

# set workdir ("~" does not work)
WORKDIR /root

# prevent "java.awt.AWTError: Assistive Technology not found: org.GNOME.Accessibility.AtkWrapper" (see https://askubuntu.com/a/723503)
RUN sed -i -e '/^assistive_technologies=/s/^/#/' /etc/java-*-openjdk/accessibility.properties

# download/compile FFmpeg
RUN wget https://www.ffmpeg.org/releases/ffmpeg-4.2.1.tar.xz -O ffmpeg.tar.xz \
 && tar -xvJf ffmpeg.tar.xz \
 && rm ffmpeg.tar.xz \
 && cd ffmpeg-* \
 && ./configure --disable-autodetect --enable-zlib --enable-librsvg --enable-gpl --disable-debug --disable-doc --disable-network --disable-ffplay --disable-avdevice --disable-swresample --disable-postproc --disable-filters --enable-filter=overlay --enable-filter=scale --enable-filter=scale_vaapi --enable-filter=format --enable-filter=hwupload --disable-hwaccels --enable-vaapi --disable-decoders --enable-decoder=h264 --enable-decoder=hevc --enable-decoder=png --enable-decoder=librsvg --disable-encoders --enable-encoder=libx264 --enable-encoder=libx265 --enable-libx264 --enable-libx265 --enable-encoder=h264_vaapi --enable-encoder=hevc_vaapi \
 && make -j `nproc` \
 && make install \
 && cd .. \
 && rm -r -f ffmpeg-*

# download/extract BaseX
RUN wget http://files.basex.org/releases/9.3/BaseX93.zip -O basex.zip \
 && unzip basex.zip -d tools \
 && rm basex.zip

# download/extract/move Saxon HE 9
RUN wget https://sourceforge.net/projects/saxon/files/Saxon-HE/9.9/SaxonHE9-9-1-6J.zip/download -O saxon.zip \
 && unzip saxon.zip saxon9he.jar \
 && mv saxon9he.jar tools/basex/lib/custom \
 && rm saxon.zip

# input/output files
RUN mkdir input output

# copy Webapp
COPY webapp/*.xqm webapp/
COPY webapp/WEB-INF/*.xml webapp/WEB-INF/
COPY create_concat_file_from_dir.xsl .
COPY .basexhome .

# expose RESTXQ port
EXPOSE 8984

# run BaseX
CMD ["tools/basex/bin/basexhttp", "-d"]