docker run -d \
  --name TranspectUI \
  -p 8001:8000 \
  -v "$(pwd)/../src/transpectui:/opt/basex/webapp/transpectui" \
  -v "$(pwd)/../src/static:/opt/basex/webapp/static" \
  -v "$(pwd)/../code:/opt/code" \
  -v "$(pwd)/../data:/opt/data" \
  -v "$(pwd)/../scripts:/opt/scripts" \
  transpectui:latest
