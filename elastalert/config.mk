# Note that I am expanding the exported environment variable ${KIBANA_VERSION}
# Uses BASH syntax due to export not makefile syntax "$(KIBANA_VERSION)"

export ELASTALERT_KIBANA_PLUGIN_DOWNLOAD=https://github.com/bitsensor/elastalert-kibana-plugin/releases/download/1.0.1/elastalert-kibana-plugin-1.0.1-${KIBANA_VERSION}.zip
