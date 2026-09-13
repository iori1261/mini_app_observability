.PHONY: up down logs verify ios

up:
	docker compose up --build

down:
	docker compose down

logs:
	docker compose logs -f api payments

verify:
	./scripts/verify-api.sh

ios:
	open ios/MiniAppObservability.xcodeproj
