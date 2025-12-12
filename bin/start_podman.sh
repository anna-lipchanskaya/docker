podman build -t python-app ../
podman run -d -p 8064:8064 --name python-app-lab --network host python-app
