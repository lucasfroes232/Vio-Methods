#!/usr/bin/env python3
"""Compatibilidade de cabecalhos ROS 2: onde o '.h' nao existe mais mas o '.hpp' existe (ex.: image_transport no Jazzy),
troca o include nos fontes. Uso: fix_includes.py <diretorio> [...]. So altera includes que podem ser provados pelo disco."""
import os, re, sys
base = "/opt/ros/%s/include" % os.environ.get("ROS_DISTRO", "jazzy")
pat = re.compile(r'(#\s*include\s*[<"])([A-Za-z0-9_]+)/([A-Za-z0-9_/]+)\.h([>"])')


def exists(pkg, rest, ext):
    return any(os.path.exists("%s/%s/%s%s" % (base, d, rest, ext)) for d in (pkg + "/" + pkg, pkg))


def fix(text, stats):
    def sub(m):
        pre, pkg, rest, post = m.groups()
        if not exists(pkg, rest, ".h") and exists(pkg, rest, ".hpp"):
            stats.append("%s/%s.h -> .hpp" % (pkg, rest))
            return "%s%s/%s.hpp%s" % (pre, pkg, rest, post)
        return m.group(0)
    return pat.sub(sub, text)


for root in sys.argv[1:]:
    for dp, _, fs in os.walk(root):
        for f in fs:
            if f.endswith((".h", ".hpp", ".cpp", ".cc", ".cxx")):
                p = os.path.join(dp, f)
                try:
                    s = open(p, encoding="utf-8").read()
                except Exception:
                    continue
                st = []
                n = fix(s, st)
                if st:
                    open(p, "w", encoding="utf-8").write(n)
                    print("fix_includes:", p, sorted(set(st)))
