#!/usr/bin/env bash
# Usage: admission-tests.sh <signed-ref> <unsigned-ref> <foreign-ref>
# Creates one namespace per policy variant (policies/<variant>.yaml selects label spike=<variant>), applies the
# policies, then tries a Pod per image in every namespace. Prints a JSON array to stdout; progress to stderr.
set -uo pipefail

declare -A REF=([signed]="$1" [unsigned]="$2" [foreign]="$3")
declare -A EXPECT=([signed]=admit [unsigned]=deny [foreign]=deny)
policies="$(cd "$(dirname "$0")/../policies" && pwd)"
variants=$(for f in "$policies"/*.yaml; do basename "$f" .yaml; done)

for v in $variants; do
  kubectl create namespace "s1-$v" >&2
  kubectl label namespace "s1-$v" "spike=$v" >&2
done
kubectl apply -f "$policies" >&2
sleep 30   # let Kyverno register the webhooks for the new policies
kubectl get imagevalidatingpolicies >&2

first=1
echo "["
for v in $variants; do
  for img in signed unsigned foreign; do
    out=$(kubectl -n "s1-$v" run "p-$img" --image="${REF[$img]}" --restart=Never 2>&1)
    if [ $? -eq 0 ]; then
      verdict=admit
      kubectl -n "s1-$v" delete pod "p-$img" --wait=false >/dev/null 2>&1
    else
      verdict=deny
    fi
    echo "$v/$img: $verdict" >&2
    [ "$first" -eq 1 ] || echo ","
    first=0
    jq -n --arg p "$v" --arg i "$img" --arg ve "$verdict" --arg ex "${EXPECT[$img]}" --arg m "$out" \
      '{policy: $p, image: $i, verdict: $ve, expected: $ex, message: $m}'
  done
done
echo "]"
