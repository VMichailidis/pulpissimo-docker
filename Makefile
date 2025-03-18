build: Dockerfile
	sudo docker build  --tag 'pulp' . 2>&1 | tee log

clean:
	docker buildx prune -f && \
	rm log

start: 
	bash run
