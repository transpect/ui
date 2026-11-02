start:
	cd docker; docker compose create; docker compose start
stop:
	cd docker; docker compose down
restart:
	cd docker; docker compose restart
build:
	cd scripts; ./buildAll.sh
rebuild:
	make build; make start
