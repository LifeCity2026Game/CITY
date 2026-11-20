# LIFE CITY — ProtonScatter

ProtonScatter is the eighth planned environment-art tool for LIFE CITY. It is an MIT-licensed Godot editor add-on by HungryProton for procedural, non-destructive placement of scenes and props on 3D geometry.

## Planned LIFE CITY use

- Trees, bushes, grass and roadside vegetation
- Rocks and beach props
- Street furniture and decorative props
- Repeatable environment dressing with fixed random seeds

## Integration

The Android build and dedicated check workflow fetch the upstream add-on at pinned commit
`7198cc00078ebde61307578137c3f35223c6e438`, copy its `addons/proton_scatter` folder into the project, verify required files and license, then run a headless Godot editor import.

The editor plugin is enabled in `project.godot`. Scatter results still need to be authored into actual LIFE CITY scenes; installing the editor tool alone does not populate the city with trees, grass or props. For mobile performance, dense scatter should be baked/cached and use reduced density/LOD on weaker devices.

Upstream: https://github.com/HungryProton/scatter  
License: MIT (see the bundled upstream `LICENSE`).  
The upstream Asset Store lists version 4.2.0 as unstable, so the Godot 4.7.2 editor import check is required before treating the integration as verified.
