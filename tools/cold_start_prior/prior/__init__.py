"""Offline cold-start prior builder for the Lighthouse AAC glow bandit.

This package is an OFFLINE, on-laptop tool. It never runs on device and ships
nothing executable into the app: its only product is a per-locale data artifact
(`out/<locale>.json`) that the app bakes in to seed the Thompson-sampling
bandit's cold-start Beta priors with context (the previously tapped button),
instead of the current context-blind per-button base_weight.

See README.md for the why and the pipeline.
"""
