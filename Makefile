.PHONY: test sh

test:
	docker-compose run --rm app bash -c "bundle install && bundle exec rake"

sh:
	docker-compose run --rm app bash -c "bundle install && bash"
