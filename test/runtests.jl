using Test
using SCENARIOGENERATION
using CSV
using JuMP, Cbc
###Gets values from csv files in the form of a dictionary###
function getValuesForEachDay(location)
    book = Dict() 
    file1 = CSV.File(location*string(1)*".csv")
    file2 = CSV.File(location*string(2)*".csv")
    file3 = CSV.File(location*string(3)*".csv")
    file4 = CSV.File(location*string(4)*".csv")
    file5 = CSV.File(location*string(5)*".csv")
    file6 = CSV.File(location*string(6)*".csv")
    file7 = CSV.File(location*string(7)*".csv")
    file8 = CSV.File(location*string(8)*".csv")
    file9 = CSV.File(location*string(9)*".csv")
    file10 = CSV.File(location*string(10)*".csv")
    file11 = CSV.File(location*string(11)*".csv")
    for i in 1:8760
        push!(book,i =>[file1[i][1],file1[i][3],file2[i][1],file2[i][3],file3[i][1],file3[i][3],file4[i][1],file4[i][3],file5[i][1],file5[i][3],file6[i][1],file6[i][3],file7[i][1],file7[i][3],file8[i][1],file8[i][3],file9[i][1],file9[i][3],file10[i][1],file10[i][3],file11[i][1],file11[i][3]])
    end
    book
end


function getTech(location)
    CSV.File(location*"gen_technology.csv")
end

#=
function model(scenarios,location) 
    transmission = getTransmission(location)
    tech = getTech(location)
    d5 = Model(with_optimizer(Cbc.Optimizer,loglevel = 0))
    @variable(d5,g[1:6]>=0) #each technologie.
    @variable(d6,c[1:11]===1) #each country, helps with keeping track of what is produced where.

    @objective(d5,Min,4*x[1]+x[2])
end
=#

function getDemand(scenarios) 
    book = Dict()
    #for i in keys(scenarios) push!(book,i => vcat(scenarios[i][1][:,1]',scenarios[i][1][:,3]',scenarios[i][1][:,5]',scenarios[i][1][:,7]',scenarios[i][1][:,9]',scenarios[i][1][:,11]',scenarios[i][1][:,13]',scenarios[i][1][:,15]',scenarios[i][1][:,17]',scenarios[i][1][:,19]',scenarios[i][1][:,21]')) end
    for i in keys(scenarios) push!(book,i => [scenarios[i][1][1],scenarios[i][1][3],scenarios[i][1][5],scenarios[i][1][7],scenarios[i][1][9],scenarios[i][1][11],scenarios[i][1][13],scenarios[i][1][15],scenarios[i][1][17],scenarios[i][1][19],scenarios[i][1][21]]) end
    book
end

function getWind(scenarios) 
    book = Dict()
    #for i in keys(scenarios) push!(book,i => vcat(scenarios[i][1][:,2]',scenarios[i][1][:,4]',scenarios[i][1][:,6]',scenarios[i][1][:,8]',scenarios[i][1][:,10]',scenarios[i][1][:,12]',scenarios[i][1][:,14]',scenarios[i][1][:,16]',scenarios[i][1][:,18]',scenarios[i][1][:,20]',scenarios[i][1][:,22]')) end
    for i in keys(scenarios) push!(book,i => [scenarios[i][1][2],scenarios[i][1][4],scenarios[i][1][6],scenarios[i][1][8],scenarios[i][1][10],scenarios[i][1][12],scenarios[i][1][14],scenarios[i][1][16],scenarios[i][1][18],scenarios[i][1][20],scenarios[i][1][22]]) end
    book
end

function getTransmission(location)
    book = Dict()
    book2 = Dict()
    transmissionFile = CSV.File(location*"transmission.csv")
    for i in 1:25 push!(book,(transmissionFile[i][2][1], transmissionFile[i][2][2]) => transmissionFile[i][3]) end
    for j in 4:12 push!(book2,transmissionFile[1][j]) end
    (book,book2)
end

#support functions for optimization.

function gSum(g,i,s) 
    sum = 0
    for j in 1:6 sum += g[i,j,s] end
    sum
end

function tSumIn(t,i,s) 
    sum = 0
    for j in 1:6 sum += t[i,j,s] end
    sum
end

function tSumOut(t,j,s)
    sum = 0
    for i in 1:11 sum += t[i,j,s] end
    sum
end

function c_vf_cost(z,x,tech,index) 
    sum = 0
    for i in 1:11 for j in 1:6 sum += tech[index[j],3] + x[i,j]*tech[index[j],4] end end
    sum
end

function transmissionCost(a,c,y)
    sum = 0
    for i in 1:11 for j in 1:11 if i<j sum += y[i,j]*(c[2] + a[i,j]*c[1]) end end end
    sum/1000
end

function scenarioSpecific(sK, sN, g, t,c, tech, g_i, u, O) 
    sum = 0
    for s in sk 
       sum1 = 0
       sum2 = 0
       sum3 = 0
       for i in 1:11 for j in 1:6 sum1 += (g[i,j,sN[s]]*(tech[g_i[j],6]+tech[g_i[j],7])) end end
       for i in 1:11 for j in 1:11 if i<j sum2 += t[i,j]*c[3] end end end
       for j in 1:11 sum3 += O*u[sN[s],j] end
       sum += (sum1 + sum2 + sum3)
    end
    sum
end

function testFunction(k)
    location = "C:\\Users\\wilha\\OneDrive\\Documents\\Julia Experiments\\Data\\"
    book = getValuesForEachDay(location)
    print(book[0])
    scenarios = wassersteinCall(book,k,nothing,1)
    sKeys = keys(scenarios)
    sKeyNr = Dict()
    n = 1
    for i in sKeys 
        push!(sKeyNr, s -> n) 
        n+=1
    end
    demand = getDemand(scenarios)
    wind = getWind(scenarios)
    probability = Dict()
    M = 10000000000
    O = 10000000000
    for i in sKeys !push(probability, i => scenarios[i][2]) end
    (avilable_transmissions,constants) = getTransmission(location)
    tech = getTech(location)
    g_index = [1,4,5,6,7,8]
    d5 = Model(with_optimizer(Cbc.Optimizer,loglevel = 0))
    @variable(d5,x[1:11 , 1:6]>=0) #each technologie in each country
    @variable(d5,z[1:11 , 1:6],Bin) #decision to invest
    @variable(d5,g[1:11, 1:6 ,1:n]>=0) #production at each scenario
    @variable(d5,y[1:11 , 1:11],Bin) #decision to transmit
    @variable(d5,t[1:11, 1:11 ,1:n]>=0) #transmission for each scenario
    @variable(d5, u[1:n, 1:11]>=0) #unmet demand of each scenario
    for i in 1:11 for j in 1:6 for s in sKeys j === 1 ? @constraint(d5,wind[s]*x[i,j]*z[i,j] >= g[i,j,sKeyNr[s]]) : @constraint(d5,x[i,j]*z[i,j] >= g[i,j,sKeyNr[s]]) end end end
    for i in 1:11 for j in 1:6 @constraint(d5,x[i,j] < M*z[i,j]) end end
    for i in 1:11 for j in 1:11 @constraint(d5,t[i,j] < M*y[i,j]) end end
    for i in 1:11 for j in 1:11 haskey(avilable_transmissions,(i,j)) || haskey(avilable_transmissions,(j,i)) ? @constraint(d5,y[i,j] < 2) : @constraint(d5,y[i,j] === 0) end end 
    for s in Skeys for j in 1:11  gSum(g,j,sKeyNr[s]) +tSumIn(t,j,sKeyNr[s]) === tSumOut(t,j,sKeyNr[s]) + demand[sKeyNr[s]] + u[sKeyNr[s],j] end  end
    @objective(d5,Min,c_vf_cost(z,x,tech,g_index) + transmissionCost(available_transmissions,constants,y) + scenarioSpecific(sKeys,sKeyNr,g,t,constants,tech,g_index,u,O))
    println(x)
end

