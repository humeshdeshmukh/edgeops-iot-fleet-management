.PHONY: help bootstrap wireguard nomad helm-install build-image lint-chart

help:
	@echo "Targets: bootstrap, wireguard, nomad, build-image, lint-chart"

bootstrap:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/bootstrap_k3s.yml

wireguard:
	ansible-playbook -i ansible/inventory.ini ansible/playbooks/configure_wireguard.yml

nomad:
	nomad job run nomad/jobs/store_app.nomad

build-image:
	docker build -t store-app:local deployments/store-app

lint-chart:
	helm lint deployments/store-app
