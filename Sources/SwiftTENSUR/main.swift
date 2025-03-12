// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation 
import SwiftTENSURTools
import MathTools
import Darwin


enum tensurError: Error {
    case parseError
    case fileError
}

let USAGE = 
"""
USAGE : \(CommandLine.arguments[0]) <coordinate file name>  <radii file> <proberad> <root out path>
            [levelspacing=0.5] [minoverlap=0.5]  [griddelta=0.15] [probeaxes=X,Y,Z]
            [isolevel=1.0] [delta=0.2] [skipcavities=yes]
            [keepreentrant=yes] [keepprobecentered=no] [minvertices=100]
            [laplaciansmoothing=yes] [smoothinglambda=0.5] [smoothingiters=10] [onlylargest=yes]
            [unitcellaxis=<x|y|z>] [unitcellorigin=<X>,<Y>,<Z>] 
            [unitcellx=<size>] [unitcelly=<size>] [unitcellz=<size>]
            [unitcellbuffer=<size>]

"""

var optdict:[String:Any] = [ "levelspacing":0.5, "minoverlap":0.5, "griddelta":0.15, "isolevel":1.0,
    "delta":0.15,   "skipcavities":true, "keepprobecentered":false, "minvertices":100,
    "keepreentrant":true , "probeaxes":[AXES.X,AXES.Y,AXES.Z],
    "laplaciansmoothing":true, "smoothinglambda":0.5, "smoothingiters":10, "onlylargest":true,
    "unitcellaxis":AXES.Z, "unitcellorigin":Vector([0.0,0.0,0.0]), 
    "unitcellx":100.0, "unitcelly":100.0, "unitcellz":100.0, "unitcellbuffer":9.0 ]

var opttypes = [ "levelspacing":"float", "minoverlap":"float", "griddelta":"float", "isolevel":"float",
    "delta":"float",  "skipcavities":"bool", "minvertices":"int",
    "keepprobecentered":"bool", "keepreentrant":"bool", "laplaciansmoothing":"bool",
    "smoothinglambda":"float" , "smoothingiters":"int", "onlylargest":"bool",
    "unitcellorigin":"vector", "unitcellx":"float", "unitcelly":"float", "unitcellz":"float",
    "unitcellbuffer":"float", "unitcellaxis":"axis", "probeaxes":"axesvector"]


// for simplicity assume paths to atomic coordinates and radii

func parseArguments() -> ([String],[String],[String]) {
    var baseArgs = [String]()
    var optArgs = [String]()
    var optValues = [String]()

    for (num,arg) in CommandLine.arguments.enumerated() {
        if num == 0 {
            continue
        }

        if arg.contains("=") {
            let tokens = arg.split(separator: "=") 
            let oarg = String(tokens[0])
            let ovalue = String(tokens[1])
            if optdict[oarg] == nil {
                print("unrecognized option \(oarg) - exit")
                exit(1)
            }

            optArgs.append(oarg)
            optValues.append(ovalue)
        }
        else {
            baseArgs.append(arg)
        }
    }

    return (baseArgs,optArgs,optValues)
}



func processOptArgs( _ keys:[String], _ values:[String]) -> [String:Any] {

    var options = optdict

    for (k,v) in zip(keys,values) {
        
         
        if options[k] == nil {
            print("warning, unknown option \(k), skipping")
            continue
        }
        let typ = opttypes[k]!

        if typ == "float" {
            let value = Double(v)
            if value == nil {
                print("warning, illegal value \(v) for option \(k), skipping")
                continue
            }

            options[k] = value
        }
        else if typ == "int" {
            let value = Int(v)
            if value == nil {
                print("warning, illegal value \(v) for option \(k), skipping")
                continue
            }

            options[k] = value
        }
        else if typ == "vector" {
            let comp = v.split { $0 == "," } .map { Double($0) }
            if comp.contains(nil) || comp.count != 3 {
                print("warning, illegal value \(v) for option \(k), skipping")
                continue
            }
            let comp2 = comp.map { $0! }
            options[k] = Vector(comp2)
        }
        else if typ == "axis" {
            
            let value = ["x":AXES.X, "y":AXES.Y, "z":AXES.Z][v]
            if value == nil {
                print("warning, illegal value \(v) for option \(k), skipping")
                continue
            }
            options[k] = value
        }
        else if typ == "axesvector" {
            let comp = v.split { $0 == "," } .map { String($0) }
            var values = [AXES]()
            for c in comp {

                let v = ["x":AXES.X, "y":AXES.Y, "z":AXES.Z, "X":AXES.X, "Y":AXES.Y, "Z":AXES.Z][c]

                if v == nil {
                    print("warning, illegal value \(v) for option \(k), skipping")
                    continue
                }

                values.append(v!)
            }

            options[k] = values
        }
        else {
            let vuse = v.lowercased() 
            if vuse == "true" || vuse == "yes" {
                options[k] = true 
            }
            else if  vuse == "false" || vuse == "no" {
                options[k] = false
            }
            else {
                print("warning, illegal value \(v) for option \(k), skipping")
                continue
            }
        }
    }

    return options 
}



func readCoords( _ path:String )  -> [Vector] {

    var txt:String?

    do {
        txt = try String(contentsOf:URL(fileURLWithPath:path), encoding: .utf8 )
    }
    catch {
        print("error, could not read file \(path), exit")
        exit(1)
    }


    let lines = txt!.split(separator:"\n")

    var coords = [Vector]()


    for line in lines {
        
        let tokens = line.split(separator: " ") 
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)}
        
        if tokens.count < 3 {
            continue
        }
        
        let x = Double(tokens[0])
        let y = Double(tokens[1])
        let z = Double(tokens[2])

        if x == nil || y == nil || z == nil {
            print("warning, could not interpret line in coordinate file :")
            print("\(line)")
            continue
        }

        let coord = Vector([x!,y!,z!])
        coords.append(coord)
        
        
    }
    
    // 
    
    return coords 
}

func readRadii(  _ path:String ) -> [Double] {

    var txt:String?

    do {
        txt = try String(contentsOf:URL(fileURLWithPath:path), encoding: .utf8 )
    }
    catch {
        print("error, could not read file \(path), exit")
        exit(1)
    }
    
    let lines = txt!.split(separator:"\n")

    var radii = [Double]()

    for line in lines {
        let tokens = line.split(separator: " ") 
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)}
        let rad = Double(tokens[0])

        if rad == nil {
            print("warning, could not interpret line in radii file :")
            print("\(line)")
            continue
        }

        radii.append(rad!)
    }
    
    return radii 
}



let argdata = parseArguments()

let baseArgs = argdata.0 
let optArgs = argdata.1
let optValues = argdata.2

let opts = processOptArgs(optArgs, optValues)

var haveUnitCell = false
var haveUnitCellArg = false

let unitCellArgs = ["unitcellaxis", "unitcellx", "unitcelly", "unitcellz", "unitcellorigin", "unitcellbuffer"]
let requiredUnitCellArgs = ["unitcellaxis", "unitcellx", "unitcelly", "unitcellz"] 
let haveUnitCellArgs = unitCellArgs .map { optArgs.contains( $0 ) }
let haveRequiredUnitCellArgs = requiredUnitCellArgs .map { optArgs.contains( $0 ) }

haveUnitCellArg = haveUnitCellArgs.contains(true)
haveUnitCell = !haveRequiredUnitCellArgs.contains(false)

var unitcell:UnitCell? = nil

let buffer = opts["unitcellbuffer"] as! Double
let levelspacing = opts["levelspacing"] as! Double
let griddelta = opts["griddelta"] as! Double

var levelspacings:[Double] = [levelspacing, levelspacing, levelspacing]
var griddeltas:[Double] = [griddelta, griddelta, griddelta]
var buffers:[Double] = [buffer, buffer, buffer]




if haveUnitCell {
    print("\nwill use unit cell with :\nX,Y,Z dimensions = \(opts["unitcellx"]!) , \(opts["unitcelly"]!) , \(opts["unitcellz"]!)")

    for (cellopt,present) in zip(unitCellArgs,haveUnitCellArgs) {
        if !present {
            print("\tnote that \(cellopt) has default value \(opts[cellopt]!)")
        }
    }

    let ux = opts["unitcellx"] as! Double
    let uy = opts["unitcelly"] as! Double
    let uz = opts["unitcellz"] as! Double

    let origin = opts["unitcellorigin"] as! Vector

    let membraneaxis = opts["unitcellaxis"] as! AXES

    let dimensions = [Vector([ux , 0.0 , 0.0]), Vector([0.0 , uy , 0.0]), Vector([0.0 , 0.0 , uz])]

    let sizes = [ ux, uy, uz ]

    

    // endforce level spacings that fit integer number of times into the unit cell dimensions for 
    // non-membrane axes


    griddeltas = [Double]()
    levelspacings = [Double]()

    for ax in 0..<3 {
        if ax == membraneaxis.rawValue {
            griddeltas.append(griddelta)
            levelspacings.append(levelspacing)
            continue
        }

        let L = round(sizes[ax]/levelspacing)
        let lspacing = sizes[ax]/L
        levelspacings.append(lspacing)
        let R = round(lspacing/griddelta)
        let gdelta = lspacing/R 
        griddeltas.append(gdelta)
    }

    // adjust buffer in X,Y and Z

    buffers = [Double]() 

    for ax in 0..<3 {
        buffers.append( round(buffer/griddeltas[ax])*griddeltas[ax] )
    }

    print("\nfor unit cell, grid deltas adjusted to \(griddeltas[0]) , \(griddeltas[1]) , \(griddeltas[2])")

    print("\nfor unit cell, buffers adjusted to \(buffers[0]) , \(buffers[1]) , \(buffers[2])")


    //unitcell = UnitCell( origin, dimensions, 
    //                        buffers!, griddeltas!, axis)
    
    unitcell = UnitCell( origin:origin, dimensions:dimensions, 
                            buffer:buffers, levelspacings:levelspacings, griddeltas:griddeltas, membraneaxis:membraneaxis)

}
else {
    if haveUnitCellArg {
        print("\nWARNING : unit cell arguments present but not all required arguments provided, unit cell not in use")
        print("\t(required = unitcellaxis, unitcellx, unitcelly, unitcellz)")
    }

}




if baseArgs.count != 4 {
    print(USAGE)
    exit(1)
}

let coordpath = baseArgs[0]
let radiipath = baseArgs[1]
let proberad = Double(baseArgs[2])!

let rootpath = baseArgs[3]

var coordinates:[Vector]?
var radii:[Double]?


coordinates = readCoords(coordpath)

radii = readRadii(radiipath)

var usecoordinates = Array(coordinates!)
var useradii = Array(radii!)

// need to keep track of original atom indices if we have membrane with buffer atoms

var atomindices:[Int]? = nil

if unitcell != nil {

    let membranedata = membraneCoordinates(coordinates!, radii!, proberad, unitcell!)

    let packedcoordinates = membranedata.0
    let imgdata = membranedata.1
    let imgradii = membranedata.2

    usecoordinates = packedcoordinates + imgdata.0
    useradii = useradii + imgradii

    // imgdata.2 has inverse map, image index back to original atom index

    atomindices = (0..<packedcoordinates.count) .map { $0 } 
                + (0..<imgdata.0.count) .map { imgdata.2[$0]! }

    


}


// get number of threads to use 

let env = ProcessInfo.processInfo.environment

var numthreads = 10

 for threadkey in ["OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS" ] {
    if env[threadkey] != nil {
        print("setting numthreads from \(threadkey)")
        let n = Int(env[threadkey]!)
        if n != nil {
            numthreads = n!
            break
        }
    }
}

// need to use fewer threads at probes step if too few atoms 

var probethreads = numthreads

if numthreads > Int(coordinates!.count / 10) {
    print("\nreduce number of probe threads due to low atom count")
    probethreads = 1
}

print("\nwill use \(numthreads) threads by default")



let minoverlap = opts["minoverlap"]! as! Double
let skipcav = opts["skipcavities"]! as! Bool

print("\ngenerate probes, parameters :")
print("\tprobe radius = \(proberad)")

if unitcell == nil {
    print("\tlevel spacing = \(levelspacing)")
    print("\tgrid spacing = \(griddelta)")
}
else {
    print("\tlevel spacings = \(levelspacings[0]) , \(levelspacings[1]) , \(levelspacings[2])")
    print("\tgrid deltas = \(griddeltas[0]) , \(griddeltas[1]) , \(griddeltas[2])")
}

print("\tminimum overlap = \(minoverlap)")
print("\tignore cavities = \(skipcav)")



let time0 = Date().timeIntervalSince1970

let theAXES = opts["probeaxes"]! as! [AXES]

// 

var surfdata = generateSurfaceProbes( coordinates:usecoordinates, radii:useradii, probeRadius:proberad, 
                    levelspacings:levelspacings, minoverlap:minoverlap, numthreads:probethreads, 
                    skipCCWContours:false, atomindices:atomindices, debugAXES:theAXES )

var probes = surfdata.0

var membraneprobes:([Probe],[Probe],[Probe])?

if unitcell != nil {
    
    membraneprobes = processMembraneProbes( probes, proberad, unitcell! )
    probes = membraneprobes!.0

}

let time1 = Date().timeIntervalSince1970

print("\nfinished generation of \(probes.count) probes, wallclock time = \(time1 - time0)")

let probepath = "\(rootpath).tensur.probes.txt"
print("\nwrite probes to \(probepath)")

func writePROBES( _ path:String, _ probes:[Probe] ) {
    let url = URL(fileURLWithPath: path )
    var outstr = ""

    for probe in probes {
        outstr += "\(probe.center.coords[0]) \(probe.center.coords[1]) \(probe.center.coords[2])"
        for aidx in probe.atoms {
            outstr += " \(aidx)"
        }
        outstr += "\n"
    }

    do {
        try outstr.write(to: url, atomically: true, encoding: String.Encoding.utf8)
    } catch {
        print("error writing probes file \(url)")
    }

}

// If membrane is in effect, the ones I want to write out are the 'keepprobes'

writePROBES( probepath, probes )



//if unitcell != nil {
//    useprobes = membraneprobedata!.0
//}


let delta = opts["delta"]! as! Double
let isolevel = opts["isolevel"]! as! Double

print("\nmarching cubes triangulation, parameters : ")
print("\ttarget grid spacing = \(griddelta)")
print("\tdensity delta parameter = \(delta)")
print("\tisolevel = \(isolevel)")



var tridata:([Vector],[Vector],[[Int]])?

do {
     tridata = try generateTriangulation( probes:probes, probeRadius:proberad, gridspacing:griddelta, 
    densityDelta:delta, isoLevel:isolevel, numthreads:numthreads, mingridchunk:20, unitcell:unitcell ) 

}
catch {
    print("triangulation code failed !")
    exit(0)
}

let time2 = Date().timeIntervalSince1970

var VERTICES = tridata!.0 
var NORMALS = tridata!.1
var FACES = tridata!.2
var COMPONENTDATA:[(vertices:[Vector],normals:[Vector],faces:[[Int]],surfacetype:SurfaceType)]?

print("\nfinished triangulation, \(FACES.count) faces, total wallclock for density + marching cubes = \(time2 - time0)")

if unitcell != nil {

    // membrane processing is currently restricive, only return the reentrant membrance components, 
    // no extra separated ligands, cavities, etc

    let membranetri = processMembraneTri( VERTICES:VERTICES, NORMALS:NORMALS, FACES:FACES, PROBES:probes, unitcell:unitcell! )

    if membranetri == nil {
        print("\nerror in membrane triangulation, exit")
        exit(1)
    }

    COMPONENTDATA = [ membranetri! ]


}
else {

    COMPONENTDATA = processNonMembraneTri( VERTICES, NORMALS, FACES, opts  )
}

let time3 = Date().timeIntervalSince1970

print("\nfinished surface processing, time = \(time3 - time2)")


//var visited = Array(repeating:false, count:VERTICES.count)
//
//func DFS(  _ v:Int, _ component: inout [Int] ) {
//
//    visited[v] = true
//    component.append(v)
//
//    for j in adjacency[v] {
//        if !visited[j] {
//            DFS( j, &component)
//        }
//    }
//}


let componentDescription = [ SurfaceType.reentrantClosed:"Reentrant", SurfaceType.probeCenteredClosed:"Probe Centered",
                               SurfaceType.reentrantCavity:"Cavity",  SurfaceType.undeterminedOpen:"Membrane"]


if COMPONENTDATA != nil {

    print("\nsurface has \(COMPONENTDATA!.count) components\n")

    for (cidx,component) in COMPONENTDATA!.enumerated() {
        let desc = componentDescription[component.surfacetype]
        print("\t\(cidx) : \(component.vertices.count) vertices, \(desc!)")
    }

}
else {
    print("\nunexpected error, no surface components, exit ")
    exit(1)
}



// 


func writeOBJ( _ path:String, _ component:(vertices:[Vector],normals:[Vector],faces:[[Int]],surfacetype:SurfaceType) ) {

    let url = URL(fileURLWithPath: path )
    var outstr = ""

    for vertex in component.vertices {
        outstr += "v \(vertex.coords[0]) \(vertex.coords[1]) \(vertex.coords[2])\n"
    }

    for normal in component.normals {
        outstr += "vn \(normal.coords[0]) \(normal.coords[1]) \(normal.coords[2])\n"
    }

    for face in component.faces {
        outstr += "f \(face[0]+1) \(face[1]+1) \(face[2]+1)\n"
    }


    do {
        try outstr.write(to: url, atomically: true, encoding: String.Encoding.utf8)
    } catch {
        print("error writing obj file \(url)")
    }
}

func updateNormals(_ component: inout (vertices:[Vector],normals:[Vector],faces:[[Int]],surfacetype:SurfaceType),
        _ adjacency:[Set<Int>]) {


    // assume counter-clockwise circulation to define face normal

    let facedata = component.faces .map { areaForFace(vertices:component.vertices, face:$0) }
    var fnormals = facedata .map { $0.normal }
    var fareas = facedata .map { $0.area }

    var nviolate = 0

    // find average of normals at each vertex, if violates original, reverse

    var vertexSum = Array(repeating:Vector([0.0,0.0,0.0]), count:component.vertices.count )
    

    for (fidx,f) in component.faces.enumerated() {
        for v in f {
            vertexSum[v] = vertexSum[v].add( fnormals[fidx].scale(fareas[fidx]) )
        }
    }

    for vidx in 0..<component.vertices.count {
        let size = vertexSum[vidx].length()
        if size < 0.0001 {
            nviolate += 1
            continue
        }

        let norm = vertexSum[vidx].scale(1.0/size)

        if norm.dot(component.normals[vidx]) < 0.0 {
            nviolate += 1
            continue
        }

        component.normals[vidx] = norm

    }

    print("\nupdate vertices after laplacian smoothing, \(nviolate) faces violated ccw orientation, were not adjusted")

}


func laplaciansmooth(_ component: inout (vertices:[Vector],normals:[Vector],faces:[[Int]],surfacetype:SurfaceType) ) {
    let lambda = opts["smoothinglambda"]! as! Double 
    let iters = opts["smoothingiters"]! as! Int 


    var boundaryVertices:Set<Int>?

    if unitcell != nil {
        let boundarydata = findBoundaryEdges( faces:component.faces )
        boundaryVertices = Set(boundarydata.vertices)
    }

    // need adjacency 

    var adj = [Set<Int>]()

    for _ in 0..<component.vertices.count {
        adj.append(Set<Int>())
    }

    for f in component.faces {
        adj[f[0]].insert(f[1])
        adj[f[1]].insert(f[0])
        adj[f[0]].insert(f[2])
        adj[f[2]].insert(f[0])
        adj[f[1]].insert(f[2])
        adj[f[2]].insert(f[1])

    }

    for iter in 0..<iters {

        for iv in 0..<component.vertices.count {

            if boundaryVertices != nil && boundaryVertices!.contains(iv) { continue }

            var sumpos = adj[iv] .reduce ( Vector([0.0,0.0,0.0]), { $0.add(component.vertices[$1])})

            sumpos = sumpos.scale(1.0/Double(adj[iv].count))

            var delta = sumpos.sub(component.vertices[iv]).scale(lambda)

            component.vertices[iv] = component.vertices[iv].add(delta)
        }
    }

    updateNormals( &component, adj )


}

// write components out in obj format

// have an open question about cavities, I have the data as to which reentrant surface a cavity is in,
// but not returning it. Not sure how to handle

var probectr_out = 0
var reent_out = 0 
var cav_out = 0

for cidx in 0..<COMPONENTDATA!.count {

    var component = COMPONENTDATA![cidx]

    var outpath = ""

    if component.surfacetype == SurfaceType.reentrantClosed || 
        component.surfacetype == SurfaceType.undeterminedOpen {
        if opts["laplaciansmoothing"]! as! Bool {
            print("laplacian smoothing for reentrant/membrane subsurface \(reent_out)")
            laplaciansmooth( &component )
         }
        
        outpath = "\(rootpath).tensur.reent.\(reent_out).obj"
        print("write reentrant surface \(reent_out) to \(outpath)")
        writeOBJ( outpath, component )
        reent_out += 1

    }
    else if component.surfacetype == SurfaceType.probeCenteredClosed {
        outpath = "\(rootpath).tensur.probectr.\(probectr_out).obj"
        print("write probe-centered surface \(probectr_out) to \(outpath)")
        writeOBJ( outpath, component )
        probectr_out += 1

    }
    else if component.surfacetype == SurfaceType.reentrantCavity {
        outpath = "\(rootpath).tensur.cavity.\(cav_out).obj"
        print("write cavity surface \(cav_out) to \(outpath)")
        writeOBJ( outpath, component )
        cav_out += 1
    }
}


let time4 = Date().timeIntervalSince1970

print("\nfinished surface generation, total wallclock = \(time4 - time0)")





