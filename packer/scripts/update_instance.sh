#!/bin/bash

set -e

zypper lr
zypper ref
zypper up
