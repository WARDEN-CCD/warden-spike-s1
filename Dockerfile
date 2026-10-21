# Minimal image: the spike tests admission, not runtime. VARIANT makes each image's digest distinct.
FROM scratch
ARG VARIANT=signed
LABEL org.opencontainers.image.source="https://github.com/WARDEN-CCD/warden-spike-s1" \
      warden.spike.variant="${VARIANT}"
COPY hello.txt /hello.txt
