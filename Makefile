# WRF Docker Makefile
COMPILE_THREADS ?= 20

.PHONY: help setup build up down restart shell logs clean wps wrf info

# Default target
help:
	@echo "WRF Docker Management Commands:"
	@echo "  make setup    - Initial setup (create directories, download data)"
	@echo "  make build    - Build Docker image"
	@echo "  make up       - Start container"
	@echo "  make down     - Stop container"
	@echo "  make restart  - Restart container"
	@echo "  make shell    - Access container shell"
	@echo "  make logs     - View container logs"
	@echo "  make clean    - Remove containers and images"
	@echo ""
	@echo "WRF/WPS Commands:"
	@echo "  make wps      - Run WPS workflow"
	@echo "  make wrf      - Run WRF (default 4 processors)"
	@echo "  make info     - Show WRF/WPS information"

# Setup project
setup:
	@chmod +x setup.sh
	@./setup.sh

# Build Docker image
build:
	docker compose build \
		--build-arg COMPILE_THREADS=$(COMPILE_THREADS) \
		--build-arg http_proxy=$(http_proxy) \
		--build-arg https_proxy=$(https_proxy) 

# Start container
up:
	docker compose up -d
	@echo "Container started. Use 'make shell' to access."

# Stop container
down:
	docker compose down

# Restart container
restart: down up

# Access container shell
shell:
	docker compose exec wrf-wps bash

# View logs
logs:
	docker compose logs -f wrf-wps

# Clean up
clean:
	@echo "This will remove all containers and images. Continue? [y/N]"
	@read ans && [ $${ans:-N} = y ] && docker compose down -v --rmi all

# Run WPS
wps:
	docker compose exec wrf-wps /wrf/scripts/run.sh wps

# Run WRF
wrf:
	docker compose exec wrf-wps /wrf/scripts/run.sh wrf 4

# Show WRF/WPS info
info:
	docker compose exec wrf-wps /wrf/scripts/wrf_info.sh

# Run real.exe
real:
	docker compose exec wrf-wps /wrf/scripts/run.sh real 4

# Run individual WPS components
geogrid:
	docker compose exec wrf-wps /wrf/scripts/run.sh geogrid

ungrib:
	docker compose exec wrf-wps /wrf/scripts/run.sh ungrib

metgrid:
	docker compose exec wrf-wps /wrf/scripts/run.sh metgrid

# Check container status
status:
	@docker compose ps

# Copy namelist files to container
copy-namelist:
	docker compose exec wrf-wps cp /wrf/config/namelist.wps /wrf/WPS/
	docker compose exec wrf-wps cp /wrf/config/namelist.input /wrf/WRF/run/
	@echo "Namelist files copied to WPS and WRF directories"

# Tail WRF output
tail-wrf:
	docker compose exec wrf-wps bash -c "tail -f /wrf/WRF/run/rsl.out.0000"

# Check WRF errors
check-errors:
	docker compose exec wrf-wps bash -c "grep -i error /wrf/WRF/run/rsl.error.* | tail -20"

# List output files
list-output:
	@echo "WRF output files:"
	@docker compose exec wrf-wps ls -la /wrf/wrfdata/output/
	@echo ""
	@echo "WPS output files:"
	@docker compose exec wrf-wps ls -la /wrf/WPS/met_em*
