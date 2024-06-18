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
            [levelspacing=0.5] [minoverlap=0.5]  [griddelta=0.15]
            [isolevel=1.0] [delta=0.1]  [epsilon=0.1] [skipcavities=yes] [volumesample=0.1]
            [laplaciansmoothing=yes] [smoothinglambda=0.5] [smoothingiters=10]
"""

var optdict:[String:Any] = [ "levelspacing":0.5, "minoverlap":0.5, "griddelta":0.15, "isolevel":1.0,
    "delta":0.1, "epsilon":0.1, "volumesample":0.1, "skipcavities":true, "keepprobecentered":false,
    "keepreentrant":true , 
    "laplaciansmoothing":true, "smoothinglambda":0.5, "smoothingiters":10]
var opttypes = [ "levelspacing":"float", "minoverlap":"float", "griddelta":"float", "isolevel":"float",
    "delta":"float", "epsilon":"float", "volumesample":"float","skipcavities":"bool",
    "keepprobecentered":"bool", "keepreentrant":"bool", "laplaciansmoothing":"bool",
    "smoothinglambda":"float" , "smoothingiters":"int"]


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
                print("unrecognized option arg - exit")
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

let surfdata = generateSurfaceProbes( coordinates:coordinates!, radii:radii!, probeRadius:proberad, 
                    levelspacing:levelspacing, minoverlap:minoverlap, numthreads:numthreads, 
                    skipCCWContours:skipcav )

let probes = surfdata.0

let time1 = Date().timeIntervalSince1970

print("\nfinished generation of \(probes.count) probes, wallclock time = \(time1 - time0)")

let gridspacing = opts["griddelta"]! as! Double
let delta = opts["delta"]! as! Double
let epsilon = opts["epsilon"]! as! Double
let isolevel = opts["isolevel"]! as! Double

print("\nmarching cubes triangulation, parameters : ")
print("\tgrid spacing = \(gridspacing)")
print("\tdensity delta = \(delta)")
print("\tdensity epsilon = \(epsilon)")




var tridata:([Vector],[Vector],[[Int]])?

do {
    tridata = try generateTriangulation( probes:probes, probeRadius:proberad, gridspacing:gridspacing, 
    densityDelta:delta, densityEpsilon:epsilon, isoLevel:isolevel, numthreads:10, mingridchunk:20 ) 
}
catch {
    print("triangulation code failed !")
    exit(0)
}

let VERTICES = tridata!.0 
let NORMALS = tridata!.1
let FACES = tridata!.2

let time2 = Date().timeIntervalSince1970

print("\nfinished marching cube triangulation, \(FACES.count) faces, wallclock time = \(time2 - time1)")

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
    let fnorms = zip(cross,areas) .map { $0.0.scale(1.0/$0.1)}

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
        print("error writing file \(url)")
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

func laplaciansmooth(_ subsurf:Int ) {
    let lambda = opts["smoothinglambda"]! as! Double 
    let iters = opts["smoothingiters"]! as! Int 

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
            var sumpos = Vector([0.0,0.0,0.0])

            for n in adj[iv] {
                sumpos = sumpos.add(SUBVERTICES[subsurf][n])
            }

            sumpos = sumpos.scale(1.0/Double(adj[iv].count))

            let delta = sumpos.sub(SUBVERTICES[subsurf][iv]).scale(lambda)

            SUBVERTICES[subsurf][iv] = SUBVERTICES[subsurf][iv].add(delta)
        }
    }


}

// write components out in obj format

if opts["keepprobecentered"]! as! Bool {

    var outcount = 0

    for subsurf in 0..<subsurfVOLUME.count {
        if subsurfVOLUME[subsurf] < 0.0 {
            let outpath = "\(rootpath).tensur.probectr.\(outcount).obj"
            print("write probe-centered surface \(subsurf) to \(outpath)")

            writeOBJ( outpath, subsurf )
            outcount += 1
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
    }

}



