cd("private_julia/repo")
println(ENV["JULIA_DEPOT_PATH"])

using Pkg
Pkg.offline()
Pkg.activate(".")
Pkg.instantiate()

using Pigeons
bench() = pigeons(target = toy_mvn_target(100), checkpoint = false, recorder_builders = [])

function run_bench()
    bench()
    return @timed bench()
end

timed = run_bench()

time = timed.time
bytes = timed.bytes 
commit = readline("commit")
date = run(`git show -s --format=%ci $commit`)
write("../../results/info.tsv", "commit\t$commit")
write("../../results/stats.csv", 
    """
    time,bytes,date
    $time,$bytes,$date
    """
)
