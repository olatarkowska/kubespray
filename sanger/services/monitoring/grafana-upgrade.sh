#!/usr/bin/env bash

helm upgrade grafana --values grafana.yaml --namespace monitoring stable/grafana