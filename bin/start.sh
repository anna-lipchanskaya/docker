docker build -t python-app .
docker run -d -p 8064:8000 --name python-app python-app

