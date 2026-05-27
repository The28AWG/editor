# Версии third-party для Make. Значения — в versions.inc.

include $(dir $(lastword $(MAKEFILE_LIST)))versions.inc
