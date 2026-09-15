# Verification Profiles in the SDD lifecycle

Repository verification profiles implement deterministic checks selected during planning and task definition. The active Spec Kit specification remains the source of intended behavior; the profile records how the repository proves relevant implementation properties.

During planning, identify the affected change types and required V0-V4 evidence. During implementation, run the applicable A0/A1 profile checks. Any A3/A4 operation remains outside automatic profile execution and follows `docs/POLICY-GATE.md`. QA uses the resulting evidence together with acceptance criteria; profile success does not replace V3/V4 evidence when those levels are required.
