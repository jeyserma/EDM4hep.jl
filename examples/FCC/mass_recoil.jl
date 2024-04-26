using EDM4hep
using EDM4hep.RootIO
using EDM4hep.SystemOfUnits
using EDM4hep.Histograms
using EDM4hep.Analysis
using DataFrames

include("analysis_functions.jl")

fnames = """
events_193400175.root
events_063734251.root
events_184128869.root
events_017670037.root
events_115460704.root
events_100167569.root
events_192636993.root
events_020572434.root
events_067932171.root
events_043326581.root
events_137485372.root
events_031357685.root
"""
froot = "root://eospublic.cern.ch//eos/experiment/fcc/ee/generation/DelphesEvents/winter2023/IDEA/wzp6_ee_mumuH_ecm240/"
files = joinpath.(Ref(froot),split(fnames))
#println(files)


export p
p(o::ReconstructedParticle) = √(o.momentum.x^2 + o.momentum.y^2 + o.momentum.z^2)


#files = "root://eospublic.cern.ch//eos/experiment/fcc/ee/generation/DelphesEvents/winter2023/IDEA/p8_ee_ZZ_ecm240/events_000189367.root"
#files = "/Users/mato/cernbox/Data/events_000189367-rntuple-rc2.root"

reader = RootIO.Reader(files);
events = RootIO.get(reader, "events");

const N = Threads.nthreads()
println(N)
const tasks_per_thread = 4

mutable struct MyData <: AbstractAnalysisData
    df::DataFrame
    pevts::Int64
    sevts::Int64
    MyData() = new(DataFrame(Zcand_m = Float32[], Zcand_recoil_m = Float32[], Zcand_q = Int32[]), 0, 0)
end

function myanalysis!(data::MyData, reader, events)
    for evt in events
        data.pevts += 1                               # count process events
        uIDs = RootIO.get(reader, evt, "Muon#0"; register=false) # get the ids of muons
        length(uIDs) < 2 && continue                  # skip if less than 2  
        
        recps = RootIO.get(reader, evt, "ReconstructedParticles"; register=false) 
        muons = recps[uIDs]                           # use the ids to subset the reco particles

        sel_muons = filter(x -> p(x) > 10GeV, muons)  # select the the Pt of muons
        data.sevts += 1 
        zed_leptonic = resonanceBuilder(91GeV, sel_muons)
        zed_leptonic_recoil = recoilBuilder(240GeV, zed_leptonic)
        if length(zed_leptonic) == 1                   #  filter to have exactly one Z candidate
            Zcand_m        = zed_leptonic[1].mass
            Zcand_recoil_m = zed_leptonic_recoil[1].mass
            Zcand_q        = zed_leptonic[1].charge
            if 80GeV <= Zcand_m <= 100GeV              # select on mass of Z candidate, push to dataframe
                push!(data.df, (Zcand_m, Zcand_recoil_m, Zcand_q))
                data.sevts += 1                        # count selected events
            end
        end
    end
    return data
end

mydata = MyData()
#subset = @view events[1:10000]
subset = events

#@info "Serial 1st run"
#@time do_analysis!(mydata, myanalysis!, reader, subset);
#@info "Serial 2nd run"
#@time do_analysis!(mydata, myanalysis!, reader, subset);
#println("Processed events: $(mydata.pevts), selected: $(mydata.sevts)")
#mydata.df |> describe |> println

@info "MT 1st run"
@time do_analysis!(mydata, myanalysis!, reader, subset; mt=true);
#Profile.clear_malloc_data()
@info "MT 2nd run"
@time do_analysis!(mydata, myanalysis!, reader, subset; mt=true);
println("Processed events: $(mydata.pevts), selected: $(mydata.sevts)")
mydata.df |> describe |> println

#using Parquet2
#Parquet2.writefile("m_H-recoil.parquet", mydata.df)

#using Plots
#histogram(sum_df.Zcand_m)

