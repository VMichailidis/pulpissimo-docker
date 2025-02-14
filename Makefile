build: Dockerfile
	sudo docker build  --tag 'pulp' .

run: 
	bash run

clean:
	docker buildx prune -f
