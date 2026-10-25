#!/bin/bash
# Resultado da compilacao de cada componente da imagem.
for n in limo_base openvins okvis2 vinsfusion; do printf "%-11s %s   %s\n" $n "$(cat /opt/status/$n 2>/dev/null || echo '?')" "$(cat /opt/status/$n.commit 2>/dev/null)"; done
echo "(logs em /opt/status/<nome>.log)"
