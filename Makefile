.PHONY: up down logs verify load load-errors ios

up:
	docker compose up --build

down:
	docker compose down

logs:
	docker compose logs -f api payments

verify:
	./scripts/verify-api.sh

# New Relic の Throughput を動かす（正常系だけ 60 件）
load:
	./scripts/load.sh 60 0

# エラー率を 30% 前後にする（100 件）
load-errors:
	./scripts/load.sh 100 30

ios:
	open ios/MiniAppObservability.xcodeproj
