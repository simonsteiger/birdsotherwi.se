### A Pluto.jl notebook ###
# v0.20.13

using Markdown
using InteractiveUtils

# ╔═╡ f0377775-6f1b-4262-88a3-f9bca19e68fa
using Distributions

# ╔═╡ 3bf675b8-78bc-4340-9734-37185f8db2ed
using DataFrames

# ╔═╡ 0324977e-cbf8-4fa1-92e6-7c4ecd1292fd
using RCall

# ╔═╡ e80a821b-9b20-4cde-bb56-5bb76ec1bcfd
using Chain

# ╔═╡ fa4493d2-88e0-495a-a546-91246e98e0d7
using BenchmarkTools

# ╔═╡ 10d3f0f2-18e4-4043-9a5a-b8da126a2880
struct Sequence
    id::Int64
    relevance::Vector{Int64}
    duration::Vector{Float64}
    function Sequence(id, relevance, duration)
        @assert length(relevance) == length(duration)
        return new(id, relevance, duration)
    end
end

# ╔═╡ b4dd1cea-1214-426d-9eab-0612c1a97ac9
Base.length(s::Sequence) = length(s.duration)

# ╔═╡ e17bf9f4-a3a1-439b-b777-0663b1347aa9
let
	x = 1:3
	view(x, 1) == view(x, 2)
end

# ╔═╡ 24e262e5-e413-46ef-93f2-53d7a525de00
function accumulate_segment(s::Sequence, i)
    accumulator = s.duration[i]
    while i < length(s) && s.relevance[i] == s.relevance[i + 1]
        accumulator += s.duration[i + 1]
        i += 1
    end
    return accumulator, i
end

# ╔═╡ 5560b5e5-6bfc-436b-93e7-4b6b6350a619
function collapse(s::Sequence)
    i = 0
    x = Sequence(s.id, Int64[], Float64[])
    while i < length(s)
        push!(x.relevance, s.relevance[i + 1])
        segment_duration, i = accumulate_segment(s, i + 1)
        push!(x.duration, segment_duration)
    end
    return x
end

# ╔═╡ 5d9d02e2-a404-4519-81ef-080a0d2ed248
function markovchain(init, trans, n)
    states = Vector{Int64}(undef, n)
    states[1] = rand(Categorical(init))
    for i in 2:n
        states[i] = rand(Categorical(trans[:, states[i - 1]]))
    end
    return states
end

# ╔═╡ 676a4d5e-62dc-4976-b2ee-41a7b7a34ecf
init = [0.3, 0.7]

# ╔═╡ 451340a8-08f6-4688-a3ab-26391cc7528e
trans = [0.8 0.4; 0.2 0.6]

# ╔═╡ c735cf11-7942-458e-b870-56494f649635
n = rand(Poisson(15), 20)

# ╔═╡ 26b23e9b-ddd0-4a6a-8b85-815c443a42cb
relevance = [markovchain(init, trans, n_i) for n_i in n]

# ╔═╡ 2d5c7430-9ee6-4bca-83c3-55d91a614c93
relevance_concat = reduce(vcat, relevance)

# ╔═╡ 290173e8-87f9-4a96-9a19-8a1df32ae468
duration = rand(Gamma(2, 1), length(relevance_concat))

# ╔═╡ 1541c625-4218-4ea0-b20e-138de38499ed
id = reduce(vcat, [fill(i, length(r)) for (i, r) in enumerate(relevance)])

# ╔═╡ 90ab0546-8158-4239-8449-72e3c0e80ec9
df = DataFrame((; id, duration, relevance = relevance_concat))

# ╔═╡ cca1081e-d50f-4676-a0ae-4f9593da3dc8
short_seqs = map(unique(df.id)) do id
	sdf = subset(df, :id => ByRow(==(id)))
	long_seq = Sequence(id, sdf.relevance, sdf.duration)
	return collapse(long_seq)
end

# ╔═╡ 1ab42b74-d04a-4c46-b654-b06d0f5db298
@rput df;

# ╔═╡ 6e4b97ea-f7c3-411e-946f-92b30ca48526
R"""
library(tidyverse)
library(bench)

r_solution <- function(df) {
  tibble(df) %>%
    mutate(
	  next_relevance = lag(relevance),
	  switch = ifelse(relevance != next_relevance & !is.na(next_relevance), 1, 0)
    ) %>%
    mutate(
      behavior_group = cumsum(switch) + 1, # If you like counting from 1, heh
	  .by = id
    ) %>%
    summarise(
	  relevance = relevance[1],
      total_duration = sum(duration),
	  .by = c(id, behavior_group)
    )
}

r_result_df <- r_solution(df)

bnch <- bench::mark(
  r_solution(df)
)
"""

# ╔═╡ c0c9d398-eecb-449d-a268-0f197943fce9
@rget r_result_df

# ╔═╡ b8bf4522-804c-471c-ba5a-5443f089e57f
short_seqs[1]

# ╔═╡ 0a07e943-eb85-4cfb-86f9-c8a5a2fd5b3c
short_seqs[2]

# ╔═╡ 5fa3ec01-3d54-4a99-9fe6-ba5fd24cdb88
# Yup, they seem to match

# ╔═╡ 8fb9574f-6cae-44a3-b124-0d78c20f3bc6
lag(x) = [first(x), x[begin:end-1]...]

# ╔═╡ d564552e-3969-4561-884e-14915d9f8487
count_switches(x) = sum(lag(x) .!= x) # we should be able to preallocate somewhat more intelligently, huh?

# ╔═╡ 28afa619-7d0a-4e24-8a0a-822f129367fe
isswitch(current, next) = current != next

# ╔═╡ a69a3ead-9481-4b0a-8dfe-d664e94fa2c6
function jl_lag(df)
	out = @chain df begin
		transform(_, :relevance => lag => :next_relevance)
		transform(_, [:relevance, :next_relevance] => ByRow(isswitch) => :switch)
		groupby(_, :id)
		transform(_, :switch => (x -> cumsum(x) .+ 1) => :behavior_group)
		groupby(_, [:id, :behavior_group])
		combine(_, [:relevance, :duration] => ((r, d) -> (relevance=first(r), 		duration=sum(d))) => AsTable)
	end
	return out
end

# ╔═╡ ee8de993-5b51-4403-b738-fbb9c9b0f449
@benchmark jl_lag($df)

# ╔═╡ 29a238a4-80d3-4493-9173-c3bd80ef2a5b
function mysolution(df)
	long_seqs = map(unique(df.id)) do id
		idx = df.id .== id
		rel = df.relevance[idx]
		dur = df.duration[idx]
		return Sequence(id, rel, dur)
	end
	return collapse.(long_seqs)
end

# ╔═╡ 5c554707-daa6-4f94-9ca5-697836b4e816
@benchmark mysolution($df)

# ╔═╡ 7a1de951-5e91-4d39-ba65-cfcbc4d8b2dc
function prep(df)
	return map(unique(df.id)) do id
		sdf = subset(df, :id => ByRow(==(id)))
		return Sequence(id, sdf.relevance, sdf.duration)
	end
end

# ╔═╡ b83271cb-a421-4d7c-b887-8bbbd8780c83
@benchmark mysolution($df)

# ╔═╡ 42ac2d3f-2978-4333-b804-a2b562bf9c9d
lag2(x) = [-Inf, x[begin:end-1]...]

# ╔═╡ 1e549785-836c-4649-9af7-2a84ac2dcc1e
segments(seq) = findall(seq .!= lag(seq))

# ╔═╡ 6496b978-e97d-4ad2-a734-869508e634b2
test_rel = [1, 2, 2, 1, 2, 2, 2, 1] # always accumulate until next -1?

# ╔═╡ 0f1fe874-c861-4770-821a-c3b178503b72
test_dur = fill(0.1, length(test_rel))

# ╔═╡ 6463c81a-d2e7-4ad2-ae52-4051737519e8
segments(test_rel)

# ╔═╡ 7ba6848e-f6a0-4a13-a8d6-ab7d6afdc06f
function collapse_test(id, rel, dur)
	finish = segments(rel)
	push!(finish, length(rel))
	
	out_rel = Vector{Int64}(undef, length(finish))
	out_dur = Vector{Float64}(undef, length(finish))
	start = 1
	for (i, fin) in enumerate(finish)
		if i == length(finish)
			out_dur[i] = dur[fin]
			out_rel[i] = rel[fin]
		else
			out_dur[i] = sum(dur[start:fin-1])
			out_rel[i] = rel[start]
		end
		start = fin
	end
	return Sequence(id, out_rel, out_dur)
end

# ╔═╡ a708f732-c894-4f3c-a0b9-f138a65218fd
function collapse_test(s::Sequence)
	finish = segments(s.relevance)
	push!(finish, length(s.relevance))
	
	out_rel = Int64[]
	out_dur = Float64[]
	start = 1
	for fin in finish
		if start == finish
			push!(out_rel, s.relevance[start])
			push!(out_dur, s.duration[start])
		else
			push!(out_rel, s.relevance[start])
			push!(out_dur, sum(s.duration[start:fin-1]))
		end
		start = fin
	end
	return Sequence(s.id, out_rel, out_dur)
end

# ╔═╡ cf94a47a-18e8-4baa-88b6-cb69255ae26b
let
	seqs = prep(df)
	@benchmark collapse_test.($seqs)
end

# ╔═╡ 56194e08-fb03-476f-912a-6ffac0f54fb9
@benchmark collapse_test($1, $test_rel, $test_dur)

# ╔═╡ bd012a59-b759-447c-a748-43425485a268
let
	seq = prep(df)
	@benchmark collapse.($seq)
end

# ╔═╡ bb01a0e0-630c-47b5-9737-9dd5183dbe94
let
	seq = prep(df)
	@benchmark collapse_test.($seq)
end

# ╔═╡ dd47fb6e-340c-44f8-9fa4-5d51d5700c57
collapse_test(1, test_rel, test_dur)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
Chain = "8be319e6-bccf-4806-a6f7-6fae938471bc"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
RCall = "6f49c342-dc21-5d91-9882-a32aef131414"

[compat]
BenchmarkTools = "~1.6.0"
Chain = "~0.6.0"
DataFrames = "~1.7.0"
Distributions = "~0.25.120"
RCall = "~0.14.6"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.5"
manifest_format = "2.0"
project_hash = "4bd21d2537f9ce8b318ded9baeaa691d50a593ae"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.BenchmarkTools]]
deps = ["Compat", "JSON", "Logging", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "e38fbc49a620f5d0b660d7f543db1009fe0f8336"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.6.0"

[[deps.CategoricalArrays]]
deps = ["DataAPI", "Future", "Missings", "Printf", "Requires", "Statistics", "Unicode"]
git-tree-sha1 = "1568b28f91293458345dabba6a5ea3f183250a61"
uuid = "324d7699-5711-5eae-9e2f-1d82baa6b597"
version = "0.10.8"

    [deps.CategoricalArrays.extensions]
    CategoricalArraysJSONExt = "JSON"
    CategoricalArraysRecipesBaseExt = "RecipesBase"
    CategoricalArraysSentinelArraysExt = "SentinelArrays"
    CategoricalArraysStructTypesExt = "StructTypes"

    [deps.CategoricalArrays.weakdeps]
    JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SentinelArrays = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
    StructTypes = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"

[[deps.Chain]]
git-tree-sha1 = "9ae9be75ad8ad9d26395bf625dea9beac6d519f1"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "0.6.0"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "8ae8d32e09f0dcf42a36b90d4e17f5dd2e4c4215"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.16.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.Conda]]
deps = ["Downloads", "JSON", "VersionParsing"]
git-tree-sha1 = "b19db3927f0db4151cb86d073689f2428e524576"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.10.2"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "fb61b4812c49343d7ef0b533ba982c46021938a6"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.7.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "4e1fe97fdaed23e9dc21d4d664bea76b65fc50a0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.22"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.Distributions]]
deps = ["AliasTables", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns"]
git-tree-sha1 = "3e6d038b77f22791b8e3472b7c633acea1ecac06"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.120"

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"
    DistributionsTestExt = "Test"

    [deps.Distributions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DensityInterface = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "6a70198746448456524cb442b8af316927ff3e1a"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.13.0"
weakdeps = ["PDMats", "SparseArrays", "Statistics"]

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStatisticsExt = "Statistics"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.HypergeometricFunctions]]
deps = ["LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "68c173f4f449de5b438ee67ed0c9c748dc31a2ec"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.28"

[[deps.InlineStrings]]
git-tree-sha1 = "6a9fde685a7ac1eb3495f8e812c5a7c3711c2d5e"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.3"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.IrrationalConstants]]
git-tree-sha1 = "e2222959fbc6c19554dc15174c81bf7bf3aa691c"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.4"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "a007feb38b422fbdab534406aeca1b86823cb4d6"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.7.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "13ca9e2586b89836fd20cccf56e57e2b9ae7f38f"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.29"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2023.12.12"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.27+1"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.5+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "f07c06228a1c670ae4c87d1276b92c7c597fdda0"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.35"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "1101cd475833706e4d0e7b122218257178f48f34"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.4.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.Profile]]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
version = "1.11.0"

[[deps.PtrArrays]]
git-tree-sha1 = "1d36ef11a9aaf1e8b74dacc6a731dd1de8fd493d"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.3.0"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "9da16da70037ba9d701192e27befedefb91ec284"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.11.2"

    [deps.QuadGK.extensions]
    QuadGKEnzymeExt = "Enzyme"

    [deps.QuadGK.weakdeps]
    Enzyme = "7da242da-08ed-463a-9acd-ee780be4f1d9"

[[deps.RCall]]
deps = ["CategoricalArrays", "Conda", "DataFrames", "DataStructures", "Dates", "Libdl", "Preferences", "REPL", "Random", "Requires", "StatsModels", "WinReg"]
git-tree-sha1 = "db17ec90d9f904b79e7877a764fdf95ff5c5f315"
uuid = "6f49c342-dc21-5d91-9882-a32aef131414"
version = "0.14.6"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "852bd0f55565a9e973fcfee83a84413270224dc4"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.8.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "58cdd8fb2201a6267e1db87ff148dd6c1dbd8ad8"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.5.1+0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "712fb0231ee6f9120e005ccd56297abbc053e7e0"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.8"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.ShiftedArrays]]
git-tree-sha1 = "503688b59397b3307443af35cd953a13e8005c16"
uuid = "1277b4bf-5013-50f5-be3d-901d8477a67a"
version = "2.0.0"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "66e0a8e672a0bdfca2c3f5937efb8538b9ddc085"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "41852b8679f78c8d8961eeadc8f62cef861a52e3"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.5.1"

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

    [deps.SpecialFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9d72a13a3f4dd3795a195ac5a44d7d6ff5f552ff"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.7.1"

[[deps.StatsBase]]
deps = ["AliasTables", "DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "b81c5035922cc89c2d9523afc6c54be512411466"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.5"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "8e45cecc66f3b42633b8ce14d431e8e57a3e242e"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.5.0"

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

    [deps.StatsFuns.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.StatsModels]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "Printf", "REPL", "ShiftedArrays", "SparseArrays", "StatsAPI", "StatsBase", "StatsFuns", "Tables"]
git-tree-sha1 = "9022bcaa2fc1d484f1326eaa4db8db543ca8c66d"
uuid = "3eaba693-59b7-5ba5-a881-562e759f1c8d"
version = "0.7.4"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "725421ae8e530ec29bcbdddbe91ff8053421d023"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.1"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "f2c1efbc8f3a609aadf318094f8fc5204bdaf344"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.VersionParsing]]
git-tree-sha1 = "58d6e80b4ee071f5efd07fda82cb9fbe17200868"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.3.0"

[[deps.WinReg]]
git-tree-sha1 = "cd910906b099402bcc50b3eafa9634244e5ec83b"
uuid = "1b915085-20d7-51cf-bf83-8f477d6f5128"
version = "1.0.0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"
"""

# ╔═╡ Cell order:
# ╠═f0377775-6f1b-4262-88a3-f9bca19e68fa
# ╠═3bf675b8-78bc-4340-9734-37185f8db2ed
# ╠═10d3f0f2-18e4-4043-9a5a-b8da126a2880
# ╠═b4dd1cea-1214-426d-9eab-0612c1a97ac9
# ╠═d564552e-3969-4561-884e-14915d9f8487
# ╠═5560b5e5-6bfc-436b-93e7-4b6b6350a619
# ╠═e17bf9f4-a3a1-439b-b777-0663b1347aa9
# ╠═24e262e5-e413-46ef-93f2-53d7a525de00
# ╠═5d9d02e2-a404-4519-81ef-080a0d2ed248
# ╠═676a4d5e-62dc-4976-b2ee-41a7b7a34ecf
# ╠═451340a8-08f6-4688-a3ab-26391cc7528e
# ╠═c735cf11-7942-458e-b870-56494f649635
# ╠═26b23e9b-ddd0-4a6a-8b85-815c443a42cb
# ╠═2d5c7430-9ee6-4bca-83c3-55d91a614c93
# ╠═290173e8-87f9-4a96-9a19-8a1df32ae468
# ╠═1541c625-4218-4ea0-b20e-138de38499ed
# ╠═90ab0546-8158-4239-8449-72e3c0e80ec9
# ╠═cca1081e-d50f-4676-a0ae-4f9593da3dc8
# ╠═0324977e-cbf8-4fa1-92e6-7c4ecd1292fd
# ╠═1ab42b74-d04a-4c46-b654-b06d0f5db298
# ╠═6e4b97ea-f7c3-411e-946f-92b30ca48526
# ╠═c0c9d398-eecb-449d-a268-0f197943fce9
# ╠═b8bf4522-804c-471c-ba5a-5443f089e57f
# ╠═0a07e943-eb85-4cfb-86f9-c8a5a2fd5b3c
# ╠═5fa3ec01-3d54-4a99-9fe6-ba5fd24cdb88
# ╠═e80a821b-9b20-4cde-bb56-5bb76ec1bcfd
# ╠═8fb9574f-6cae-44a3-b124-0d78c20f3bc6
# ╠═28afa619-7d0a-4e24-8a0a-822f129367fe
# ╠═fa4493d2-88e0-495a-a546-91246e98e0d7
# ╠═a69a3ead-9481-4b0a-8dfe-d664e94fa2c6
# ╠═ee8de993-5b51-4403-b738-fbb9c9b0f449
# ╠═5c554707-daa6-4f94-9ca5-697836b4e816
# ╠═29a238a4-80d3-4493-9173-c3bd80ef2a5b
# ╠═7a1de951-5e91-4d39-ba65-cfcbc4d8b2dc
# ╠═cf94a47a-18e8-4baa-88b6-cb69255ae26b
# ╠═b83271cb-a421-4d7c-b887-8bbbd8780c83
# ╠═42ac2d3f-2978-4333-b804-a2b562bf9c9d
# ╠═1e549785-836c-4649-9af7-2a84ac2dcc1e
# ╠═6496b978-e97d-4ad2-a734-869508e634b2
# ╠═0f1fe874-c861-4770-821a-c3b178503b72
# ╠═6463c81a-d2e7-4ad2-ae52-4051737519e8
# ╠═7ba6848e-f6a0-4a13-a8d6-ab7d6afdc06f
# ╠═a708f732-c894-4f3c-a0b9-f138a65218fd
# ╠═56194e08-fb03-476f-912a-6ffac0f54fb9
# ╠═bd012a59-b759-447c-a748-43425485a268
# ╠═bb01a0e0-630c-47b5-9737-9dd5183dbe94
# ╠═dd47fb6e-340c-44f8-9fa4-5d51d5700c57
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
