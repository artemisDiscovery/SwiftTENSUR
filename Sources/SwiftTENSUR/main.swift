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
            [isolevel=1.0] [delta=0.1]  [epsilon=0.1] [skipcavities=yes] [volumesample=0.1]
            [laplaciansmoothing=yes] [smoothinglambda=0.5] [smoothingiters=10] [onlylargest=yes]
            [unitcellaxis=<'x'|'y'|'z'>] [unitcellorigin=<X>,<Y>,<Z>] 
            [unitcellx=<size>] [unitcelly=<size>] [unitcellz=<size>]
            [unitcellbuffer=<size>]

"""

var optdict:[String:Any] = [ "levelspacing":0.5, "minoverlap":0.5, "griddelta":0.15, "isolevel":1.0,
    "delta":0.1, "epsilon":0.1, "volumesample":0.1, "skipcavities":false, "keepprobecentered":false,
    "keepreentrant":true , "probeaxes":[AXES.X,AXES.Y,AXES.Z],
    "laplaciansmoothing":true, "smoothinglambda":0.5, "smoothingiters":10, "onlylargest":true,
    "unitcellaxis":AXES.Z, "unitcellorigin":Vector([0.0,0.0,0.0]), 
    "unitcellx":100.0, "unitcelly":100.0, "unitcellz":100.0, "unitcellbuffer":4.0 ]

var opttypes = [ "levelspacing":"float", "minoverlap":"float", "griddelta":"float", "isolevel":"float",
    "delta":"float", "epsilon":"float", "volumesample":"float","skipcavities":"bool",
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

if haveUnitCell {
    print("\nwill use unit cell with :\nX,Y,Z dimensions = \(opts["unitcellx"]) , \(opts["unitcelly"]) , \(opts["unitcellz"])")

    for (cellopt,present) in zip(unitCellArgs,haveUnitCellArgs) {
        if !present {
            print("\tnote that \(cellopt) has default value \(opts[cellopt])")
        }
    }

    let ux = opts["unitcellx"] as! Double
    let uy = opts["unitcelly"] as! Double
    let uz = opts["unitcellz"] as! Double

    let origin = opts["unitcellorigin"] as! Vector

    let buffer = opts["unitcellbuffer"] as! Double

    let axis = opts["unitcellaxis"] as! AXES

    
    let dimensions = [Vector([ux , 0.0 , 0.0]), Vector([0.0 , uy , 0.0]), Vector([0.0 , 0.0 , uz])]
    unitcell = UnitCell( origin, dimensions, 
    [buffer, buffer, buffer], axis)

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

print("\nwill use \(numthreads) threads")



let levelspacing = opts["levelspacing"]! as! Double
let minoverlap = opts["minoverlap"]! as! Double
let skipcav = opts["skipcavities"]! as! Bool

print("\ngenerate probes, parameters :")
print("\tprobe radius = \(proberad)")
print("\tlevel spacing = \(levelspacing)")
print("\tminimum overlap = \(minoverlap)")
print("\tignore cavities = \(skipcav)")



let time0 = Date().timeIntervalSince1970

let theAXES = opts["probeaxes"] as! [AXES]

var surfdata = generateSurfaceProbes( coordinates:usecoordinates, radii:useradii, probeRadius:proberad, 
                    levelspacing:levelspacing, minoverlap:minoverlap, numthreads:probethreads, 
                    skipCCWContours:skipcav, unitcell:unitcell, atomindices:atomindices, debugAXES:theAXES )

var probes = surfdata.0

var membraneprobedata:([Probe],[Probe],[Probe])?

if unitcell != nil {

    membraneprobedata = processMembraneProbes( probes, proberad, unitcell! )
    probes = membraneprobedata!.1
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

var useprobes = probes 

if unitcell != nil {
    useprobes = membraneprobedata!.0
}


let gridspacing = opts["griddelta"]! as! Double
let delta = opts["delta"]! as! Double
let epsilon = opts["epsilon"]! as! Double
let isolevel = opts["isolevel"]! as! Double

print("\nmarching cubes triangulation, parameters : ")
print("\tgrid spacing = \(gridspacing)")
print("\tdensity delta = \(delta)")
print("\tdensity epsilon = \(epsilon)")
print("\tisolevel = \(isolevel)")




var tridata:([Vector],[Vector],[[Int]])?

do {
    tridata = try generateTriangulation( probes:useprobes, probeRadius:proberad, gridspacing:gridspacing, 
    densityDelta:delta, densityEpsilon:epsilon, isoLevel:isolevel, numthreads:numthreads, mingridchunk:20 ) 
}
catch {
    print("triangulation code failed !")
    exit(0)
}

var VERTICES = tridata!.0 
var NORMALS = tridata!.1
var FACES = tridata!.2

if unitcell != nil {

    let membranetri = processMembraneTri( VERTICES, NORMALS, FACES, unitcell! )

    VERTICES = membranetri.0
    NORMALS = membranetri.1
    FACES = membranetri.2

}


let time2 = Date().timeIntervalSince1970

print("\nfinished triangulation, \(FACES.count) faces, total wallclock for density + marching cubes = \(time2 - time0)")

// find connected components

var adjacency = [Set<Int>]()

for _ in 0..<VERTICES.count {
    adjacency.append(Set<Int>())
}

for f in FACES {
    adjacency[f[0]].insert(f[1])
    adjacency[f[1]].insert(f[0])
    adjacency[f[0]].insert(f[2])
    adjacency[f[2]].insert(f[0])
    adjacency[f[1]].insert(f[2])
    adjacency[f[2]].insert(f[1])

}

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

// to avoid recursion stack size issue, see if we can manage our own stack for component identification

var STACK = [[Int]]()

var visited = Array(repeating:false, count:VERTICES.count)
var component = Array(repeating:-1, count:VERTICES.count)

var currentComponent = -1
var unassigned:Int?

while true {
    //find first unassigned vertex

    unassigned = nil

    for iv in 0..<VERTICES.count {
        if component[iv] < 0 {
            unassigned = iv
            break
        }
    }
    if unassigned == nil {
        break
    }

    currentComponent += 1

    STACK.append([unassigned!,currentComponent])

    while STACK.count > 0 {
        let data = STACK.popLast()!
        if !visited[data[0]] {
            visited[data[0]] = true 
            component[data[0]] = data[1]
            for iv in adjacency[data[0]] {
                STACK.append([iv,currentComponent])
            }
        }
    }
}

var components = [[Int]]()

for c in 0..<(currentComponent+1) {
    components.append([Int]())
}

for (iv,c) in component.enumerated() {
    components[c].append(iv)
}


print("\nsurface has \(components.count) components")

// assign subsurfaces (vertices, normals, faces)


var SUBVERTICES = [[Vector]]()
var SUBNORMALS = [[Vector]]()
var SUBFACES = [[[Int]]]()

// sort components by decreasing size

components = components .sorted { $0.count > $1.count }

for comp in components {
    let subvertindices = comp .sorted { $0 < $1 }
    var vertexmap = Array(repeating:-1, count:VERTICES.count)

    _ = subvertindices.enumerated() .map { vertexmap[$0.1] = $0.0 }

    let subvertices = subvertindices .map { VERTICES[$0] }
    let subnormals = subvertindices .map { NORMALS[$0] }

    let subfaces = FACES .filter { vertexmap[$0[0]] >= 0 } 
        .map { [vertexmap[$0[0]], vertexmap[$0[1]], vertexmap[$0[2]]] }

    SUBVERTICES.append( subvertices )
    SUBNORMALS.append( subnormals )
    SUBFACES.append( subfaces )
}

// 

if unitcell != nil {

    if SUBVERTICES.count < 4 {
        print("\nerror, have membrane but only \(SUBVERTICES.count) surface components")
        exit(1)
    }
    let membraneCompData = membraneSurfaceComponents( SUBVERTICES, SUBNORMALS, SUBFACES, unitcell! )

    SUBVERTICES = membraneCompData.0
    SUBNORMALS = membraneCompData.1
    SUBFACES = membraneCompData.2
}


// get signed 'volume' sample for surfaces, using specified fraction of faces

let SELECT_FRAC = opts["volumesample"]! as! Double

// for each subsurface, select fraction of faces, for each face compute centroid and face normal
var subsurfVOLUME = [ Double ]()


for isurf in 0..<SUBVERTICES.count {
    let randomsel = SUBFACES[isurf] .filter { _ in drand48() < SELECT_FRAC }
    let subverts = SUBVERTICES[isurf]
    let subnorms = SUBNORMALS[isurf]

    
    let corners = randomsel .map { [subverts[$0[0]], subverts[$0[1]], subverts[$0[2]]] }
    var centroids = corners .map { $0[0].add($0[1]).add($0[2]).scale(1.0/3.0)}
    var center = centroids .reduce( Vector([0.0,0.0,0.0]) ) { $0 + $1 }
    center = center.scale(1.0/Double(centroids.count))

    centroids = centroids .map { $0.sub(center) }

    let avenorms =   randomsel .map { subnorms[$0[0]] + subnorms[$0[1]] + subnorms[$0[2]] }

    var cross = corners .map { $0[1].sub($0[0]).cross($0[2].sub($0[0])) }
    // flip if not in agreement with vertex normals
    let sgns = zip(cross,avenorms) .map { (x) in
        let dot = x.0.dot(x.1)
        if dot < 0.0 {
            return -1.0
        } 
        return 1.0
    }

    cross = zip(cross,sgns) .map { $0.0.scale($0.1) }
    let areas = cross .map { $0.length() }
    // had a random error on linux, maybe the denominator was zero? This is the only danger spot I see ...
    let fnorms = zip(cross,areas) .map { $0.0.scale(1.0/($0.1 + 0.000001))}

    // sum of centroid positions .dot face normals gives volume sample

    let vol = zip(centroids,fnorms) .map { $0.0.dot($0.1) as! Double } .reduce (0.0) { $0 + $1 }

    subsurfVOLUME.append(vol)

}

print("\nsubsurface data:")
for j in 0..<SUBVERTICES.count {
    print("\t\(j) : #vertices = \(SUBVERTICES[j].count) , #faces = \(SUBFACES[j].count), volume sample = \(subsurfVOLUME[j])")
}


func writeOBJ( _ path:String, _ subsurf:Int ) {

    let url = URL(fileURLWithPath: path )
    var outstr = ""

    for vertex in SUBVERTICES[subsurf] {
        outstr += "v \(vertex.coords[0]) \(vertex.coords[1]) \(vertex.coords[2])\n"
    }

    for normal in SUBNORMALS[subsurf] {
        outstr += "vn \(normal.coords[0]) \(normal.coords[1]) \(normal.coords[2])\n"
    }

    for face in SUBFACES[subsurf] {
        outstr += "f \(face[0]+1) \(face[1]+1) \(face[2]+1)\n"
    }


    do {
        try outstr.write(to: url, atomically: true, encoding: String.Encoding.utf8)
    } catch {
        print("error writing obj file \(url)")
    }
}

func updateNormals(_ subsurf:Int) {

    // vertex face adjaceny

    var fadj = [Set<Int>]()

    for iv in 0..<SUBVERTICES[subsurf].count {
        fadj.append(Set<Int>())
    }

    for (fidx,f) in SUBFACES[subsurf].enumerated() {
        fadj[f[0]].insert(fidx)
        fadj[f[1]].insert(fidx)
        fadj[f[2]].insert(fidx)
    }

    // assume counter-clockwise circulation to define face normal

    var fnormals = [Vector]()
    var fareas = [Double]()

    var nviolate = 0

    for (fidx,f) in SUBFACES[subsurf].enumerated() {
        let r01 = SUBVERTICES[subsurf][f[1]].sub(SUBVERTICES[subsurf][f[0]])
        let r02 = SUBVERTICES[subsurf][f[2]].sub(SUBVERTICES[subsurf][f[0]])
        let n = r01.cross(r02)
        let area = n.length()
        var nnorm = n.scale(1.0/area)
        fareas.append(area)
        let normsum = SUBNORMALS[subsurf][f[0]].add(SUBNORMALS[subsurf][f[1]]).add(SUBNORMALS[subsurf][f[2]])
        if nnorm.dot(normsum) < 0.0 {
            nviolate += 1
            nnorm = nnorm.scale(-1.0)
        }
        fnormals.append(nnorm)

    }

    // update vertex normals as average of adjacent face normals

    for iv in 0..<SUBVERTICES[subsurf].count {
        var avenorm = Vector([0.0, 0.0, 0.0])

        for fidx in fadj[iv] {
            avenorm = avenorm.add(fnormals[fidx])
        }

        avenorm = avenorm.scale(1.0/Double(fadj[iv].count))
        SUBNORMALS[subsurf][iv] = avenorm
    }

    print("\nupdate vertices after laplacian smoothing, \(nviolate) faces violated ccw orientation")

}

struct Edge : Hashable {
    var v1:Int
    var v2:Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(v1)
        hasher.combine(v2)
    }
}

func laplaciansmooth(_ subsurf:Int ) {
    let lambda = opts["smoothinglambda"]! as! Double 
    let iters = opts["smoothingiters"]! as! Int 

    var boundaryVertices:Set<Int>? = nil

    if unitcell != nil {
        // identify vertices at boundary of mesh 

        var edgeToFaces = [Edge:[Int]]()

        for (fidx,face) in SUBFACES[subsurf].enumerated() {

            for vindices in [[face[0],face[1]],[face[1],face[2]],[face[0],face[2]]] {
                let v1 = vindices.min()!
                let v2 = vindices.max()!
                let edge = Edge(v1:v1, v2:v2)
                if edgeToFaces[edge] == nil {
                    edgeToFaces[edge] = []
                }
                edgeToFaces[edge]!.append(fidx)
            
            }

        }

        boundaryVertices = Set<Int>()

        for edge in edgeToFaces.keys {

            if edgeToFaces[edge]!.count == 1 {
                boundaryVertices!.insert(edge.v1)
                boundaryVertices!.insert(edge.v2)
            }
        }

    }

    // need adjacency 

    var adj = [Set<Int>]()

    for _ in 0..<SUBVERTICES[subsurf].count {
        adj.append(Set<Int>())
    }

    for f in SUBFACES[subsurf] {
        adj[f[0]].insert(f[1])
        adj[f[1]].insert(f[0])
        adj[f[0]].insert(f[2])
        adj[f[2]].insert(f[0])
        adj[f[1]].insert(f[2])
        adj[f[2]].insert(f[1])

    }

    for iter in 0..<iters {
        for iv in 0..<SUBVERTICES[subsurf].count {

            if boundaryVertices != nil && boundaryVertices!.contains(iv) { continue }

            var sumpos = Vector([0.0,0.0,0.0])

            for n in adj[iv] {
                sumpos = sumpos.add(SUBVERTICES[subsurf][n])
            }

            sumpos = sumpos.scale(1.0/Double(adj[iv].count))

            var delta = sumpos.sub(SUBVERTICES[subsurf][iv]).scale(lambda)

            SUBVERTICES[subsurf][iv] = SUBVERTICES[subsurf][iv].add(delta)
        }
    }


}

// write components out in obj format
// if onlylargest = true, only write out largest of any type

if opts["keepprobecentered"]! as! Bool {

    var outcount = 0

    for subsurf in 0..<subsurfVOLUME.count {
        if subsurfVOLUME[subsurf] < 0.0 {
            let outpath = "\(rootpath).tensur.probectr.\(outcount).obj"
            print("write probe-centered surface \(subsurf) to \(outpath)")

            writeOBJ( outpath, subsurf )
            outcount += 1
        }

        if opts["onlylargest"] as! Bool == true && outcount == 1 {
            break
        }
    }

}

if opts["keepreentrant"]! as! Bool {

    var outcount = 0

    for subsurf in 0..<subsurfVOLUME.count {
        if subsurfVOLUME[subsurf] > 0.0 {
            // invert vertex normals

            // SUBNORMALS[subsurf] = SUBNORMALS[subsurf] .map { $0.scale(-1.0)}

            if opts["laplaciansmoothing"]! as! Bool {
                print("laplacian smoothing for subsurface \(subsurf)")
                laplaciansmooth( subsurf )
                print("update normals for subsurface \(subsurf)")
                updateNormals(subsurf)
            }

            let outpath = "\(rootpath).tensur.reentrant.\(outcount).obj"
            print("write reentrant surface \(subsurf) to \(outpath)")

            writeOBJ( outpath, subsurf )
            outcount += 1
        }

        if opts["onlylargest"] as! Bool == true && outcount == 1 {
            break
        }
    }

let time3 = Date().timeIntervalSince1970

print("\nfinished surface generation, total wallclock = \(time3 - time0)")

}



