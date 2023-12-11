using Revise
using EDM4hep
using DataFrames
using EDM4hep.RootIO

f = "/Users/mato/Downloads/example_edm4hep2.root"

reader = RootIO.Reader(f)
events = RootIO.get(reader, "events")
evt = events[1];

set_hits = RootIO.get(reader, evt, "SETCollection")
mcps =  RootIO.get(reader, evt, "MCParticle")

for hit in set_hits
    println("Hit $(hit.index) is related to MCParticle $(hit.mcparticleidx)")
end

DataFrame(set_hits)
DataFrame(mcps)[!,14:15]
parents =  RootIO.get(reader, evt, "_MCParticle_parents")
