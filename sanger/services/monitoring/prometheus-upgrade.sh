#!/usr/bin/env bash

helm upgrade prometheus --values prometheus.yaml --namespace monitoring stable/prometheus