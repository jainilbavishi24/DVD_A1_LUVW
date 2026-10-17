# Render the final GDSII to the two report screenshots with KLayout in batch mode.
# Run inside IIC-OSIC-TOOLS from the repository root:
#   klayout -zz -r render_layout.py
import os
import klayout.db as db
import klayout.lay as lay

gds = "pnr/mult_array.gds"
lyp = os.path.join(os.environ.get("PDK_ROOT", "/foss/pdks"), "sky130A/libs.tech/klayout/tech/sky130A.lyp")

view = lay.LayoutView()
view.set_config("background-color", "#ffffff")
view.set_config("grid-visible", "false")
view.set_config("text-visible", "false")
view.load_layout(gds, True)
view.load_layer_props(lyp)
view.max_hier()

# Whole 150 um x 150 um die.
view.zoom_fit()
view.save_image("report/layout_whole_die.png", 1000, 1000)

# Close-up near the core centre: standard-cell rows, power rails and routed metal.
view.zoom_box(db.DBox(55, 55, 95, 85))
view.save_image("report/layout_zoomed.png", 1200, 900)
print("wrote report/layout_whole_die.png and report/layout_zoomed.png")
