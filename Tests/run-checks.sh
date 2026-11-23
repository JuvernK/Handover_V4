#!/bin/sh
# Compiles and runs each standalone check against the app sources it covers.
# Usage, from the repository root: sh Tests/run-checks.sh
set -eu

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

run() {
    name="$1"
    shift
    xcrun swiftc -parse-as-library -default-isolation MainActor "$@" -o "$out/$name"
    "$out/$name"
}

orbit=Handover_V4/Presentation/Orbit
dashboard=Handover_V4/Presentation/Dashboard

run orbit Tests/OrbitPresentationStateChecks.swift \
    "$orbit/OrbitPresentationState.swift" "$orbit/OrbitController.swift" "$orbit/OrbitPath.swift"
run dashboard Tests/DashboardPresentationStateChecks.swift \
    "$dashboard/DashboardPresentationState.swift"
run board Tests/DashboardBoardChecks.swift \
    "$dashboard/DashboardBoardState.swift" "$dashboard/DashboardPresentationState.swift"
run shareplay Tests/SharedHandoverReplicaChecks.swift \
    Handover_V4/SharePlay/SharedHandoverReplica.swift Handover_V4/SharePlay/SharedHandoverSnapshot.swift \
    Handover_V4/Presentation/Controls/PresentationMode.swift "$orbit/OrbitPresentationState.swift" \
    "$dashboard/DashboardPresentationState.swift" "$dashboard/DashboardBoardState.swift"
run patients Tests/PatientSummaryChecks.swift \
    Handover_V4/Models/Patient.swift Handover_V4/Models/Enums.swift Handover_V4/Data/PatientDataLoader.swift
