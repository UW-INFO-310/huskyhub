# Optional helpers; equivalent Docker commands are documented in the labs.
.PHONY: up down reset logs shell-db ai-setup ai-container-setup

up:
	docker compose up --build

down:
	docker compose --profile ai down

reset:
	@echo "WARNING: deletes database and container-model volumes; repeat data migrations afterwards."
	docker compose --profile ai down -v
	docker compose up --build

logs:
	docker compose logs -f

shell-db:
	docker compose exec huskyhub-db sh -c 'exec mysql -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"'

# Native Ollama must already be installed and running; see Week 9 pre-lab.
ai-setup:
	ollama pull llama3.2
	docker compose up -d --build huskyhub-flask

# First set OLLAMA_BASE_URL=http://huskyhub-ollama:11434 in .env.
ai-container-setup:
	docker compose --profile ai up -d
	docker compose exec huskyhub-ollama ollama pull llama3.2
	docker compose up -d --force-recreate huskyhub-flask
