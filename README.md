# AgieCharmilles Post Processor

This is a Fusion 360 Post-Processor to generate simple .ISO files for use with older (and possibly newer) AgieCharmilles Wire EDM Machines inside of Fusion 360.
This has been tested on an AgieCharmilles AC Classic V2 using the provided tool library.

Use the provided tool library in Fusion 360 (tool will load as a plasma cutter). Use a "2D Profile Cutting" operation in the "Fabrication" inside of the "Manufacturing" workspace. Make sure you remove any lead-in or lead-outs on the profile so you just get the outline of the part. You can then use the "agiecharmilles.cps" post-processor to export a .ISO file for use withing AgieVision. Make sure to set your units to Inches inside of the post-processor window to ensure proper scaling.

> [!WARNING]
> I am not responsible for any damage to your EDM machine. This post processor could have bugs and should be used with caution.
