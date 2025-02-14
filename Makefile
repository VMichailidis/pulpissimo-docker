build: Dockerfile
	sudo docker build  --tag 'pulp' .

clean:
	docker buildx prune -f

start: 
	bash run
