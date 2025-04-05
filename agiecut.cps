description = "AgieCharmilles AC Classic V2 Post Processor";
vendor = "Brandon Wees";
vendorUrl = "https:/bwees.io";
legal = "Copyright (C) 2025 by Brandon Wees. All rights reserved.";
certificationLevel = 2;
minimumRevision = 24000;

longDescription = "AgieCharmilles AC Classic V2 Post Processor";

extension = "ISO";
setCodePage("ascii");

capabilities = CAPABILITY_JET;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = 1 << PLANE_XY; // only XY



var gFormat = createFormat({prefix:"G", decimals:0, minDigitsLeft:2});
var mFormat = createFormat({prefix:"M", decimals:0, minDigitsLeft:2});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});

var xOutput = createVariable({prefix:"X", decimals: 1, forceDecimal: true}, xyzFormat);
var yOutput = createVariable({prefix:"Y", decimals: 1, forceDecimal: true}, xyzFormat);
var zOutput = createVariable({prefix:"Z", decimals: 1, forceDecimal: true}, xyzFormat);

var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({prefix:"B"}, abcFormat);
var cOutput = createVariable({prefix:"C"}, abcFormat);

// circular output
var iOutput = createReferenceVariable({prefix:"I", decimals: 1, forceDecimal: true}, xyzFormat);
var jOutput = createReferenceVariable({prefix:"J", decimals: 1, forceDecimal: true}, xyzFormat);

var gMotionModal = createModal({force:true}, gFormat); // modal group 1 // G0-G3, ...
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91

// collected state
var sequenceNumber = 100;
var initialG31 = false;
var hasSentG90 = false;

/**
 Writes the specified block.
 */
function writeBlock() {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += 10;

}

function onOpen() {
    writeBlock(gFormat.format(70), ";");
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
    xOutput.reset();
    yOutput.reset();
    zOutput.reset();
}

/** Force output of A, B, and C. */
function forceABC() {
    aOutput.reset();
    bOutput.reset();
    cOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
    forceXYZ();
    forceABC();
}

var currentWorkPlaneABC = undefined;

function forceWorkPlane() {
    currentWorkPlaneABC = undefined;
}

var closestABC = false; // choose closest machine angles
var currentMachineABC;

function getWorkPlaneMachineABC(workPlane) {
    var W = workPlane; // map to global frame

    var abc = machineConfiguration.getABC(W);
    if (closestABC) {
        if (currentMachineABC) {
            abc = machineConfiguration.remapToABC(abc, currentMachineABC);
        } else {
            abc = machineConfiguration.getPreferredABC(abc);
        }
    } else {
        abc = machineConfiguration.getPreferredABC(abc);
    }

    try {
        abc = machineConfiguration.remapABC(abc);
        currentMachineABC = abc;
    } catch (e) {
        error(
            localize("Machine angles not supported") + ":"
            + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
            + conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
            + conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
        );
    }

    var direction = machineConfiguration.getDirection(abc);
    if (!isSameDirection(direction, W.forward)) {
        error(localize("Orientation not supported."));
        return new Vector();
    }

    if (!machineConfiguration.isABCSupported(abc)) {
        error(
            localize("Work plane is not supported") + ":"
            + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
            + conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
            + conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
        );
    }

    var tcp = false;
    if (tcp) {
        setRotation(W); // TCP mode
    } else {
        var O = machineConfiguration.getOrientation(abc);
        var R = machineConfiguration.getRemainingOrientation(abc, W);
        setRotation(R);
    }

    return abc;
}

function onSection() {

    writeln("");

}


function onRapid(_x, _y, _z) {
    var x = xOutput.format(_x);
    var y = yOutput.format(_y);

    if (x == "" && y == "") {
        // no need to output a rapid move
        return;
    }
    
    writeBlock(gMotionModal.format(0), x, y, ";");
}

function onLinear(_x, _y, _z, feed) {
    var x = xOutput.format(_x);
    var y = yOutput.format(_y);

    if (!hasSentG90) {
        writeBlock(gAbsIncModal.format(90), ";");
        hasSentG90 = true;
    }
    
    writeBlock(gMotionModal.format(1), x, y, ";");
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
    error(localize("This post processor does not support 5-axis simultaneous toolpath."));
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
    error(localize("This post processor does not support 5-axis simultaneous toolpath."));
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {

    if (!hasSentG90) {
        writeBlock(gAbsIncModal.format(90), ";");
        hasSentG90 = true;
    }

    var start = getCurrentPosition();

    if (isFullCircle()) {
        if (isHelical()) {
            linearize(tolerance);
            return;
        }
        switch (getCircularPlane()) {
            case PLANE_XY:
                writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), ";");
                break;
            default:
                linearize(tolerance);
        }
    } else {
        switch (getCircularPlane()) {
            case PLANE_XY:
                writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), ";");
                break;
            default:
                linearize(tolerance);
        }
    }
}

function onClose() {
    writeBlock(mFormat.format(2), ";");
    writeln("");
}