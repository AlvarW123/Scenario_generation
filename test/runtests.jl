using Test
using SCENARIOGENERATION
using CSV
using JuMP,Cbc
using Gurobi
using Plots
using LightGraphs
using GraphRecipes
using StatsPlots
###Gets values from csv files in the form of a dictionary###

"""Get values from csv files for each region"""
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

"""Get values for each technology"""
function getTech(location)
    CSV.File(location*"gen_technology.csv")
end

function getDemand(scenarios) 
    book = Dict()
    for i in keys(scenarios) push!(book,i => [scenarios[i][1][1],scenarios[i][1][3],scenarios[i][1][5],scenarios[i][1][7],scenarios[i][1][9],scenarios[i][1][11],scenarios[i][1][13],scenarios[i][1][15],scenarios[i][1][17],scenarios[i][1][19],scenarios[i][1][21]]) end
    book
end

function getWind(scenarios) 
    book = Dict()
    for i in keys(scenarios) push!(book,i => [scenarios[i][1][2],scenarios[i][1][4],scenarios[i][1][6],scenarios[i][1][8],scenarios[i][1][10],scenarios[i][1][12],scenarios[i][1][14],scenarios[i][1][16],scenarios[i][1][18],scenarios[i][1][20],scenarios[i][1][22]]) end
    book
end

function getTransmission(location)
    book = Dict()
    book2 = []
    transmissionFile = CSV.File(location*"transmission.csv")
    for i in 1:25 push!(book,(getNr(transmissionFile[i][2][1:4]), getNr(transmissionFile[i][2][4:length(transmissionFile[i][2])])) => transmissionFile[i][3]) end
    for j in 4:12 push!(book2,transmissionFile[1][j]) end
    (book,book2)
end



function getNr(str)
    numbers = "0123456789"
    number = ""
    for s in str if contains(numbers,s) number = number*s end end
    parse(Int,number)
end

function testScenario(k)
    println("Hallo?")
    location = "C:\\Users\\wilha\\OneDrive\\Documents\\Julia Experiments\\Data\\"
    book = getValuesForEachDay(location)
    println("Hallo2")
    scenarios = wassersteinCall(book,k,nothing,1) #calls a function
    #scenarios = kclusterMethod(book,k)
    #scenarios = samplingMethod(book,k)
    println("Hallo3")
    sKeys = keys(scenarios)
    sKeyNr = Dict()
    n = 1 #represents the number of scenarios
    for s in sKeys #indexes the keyset
        push!(sKeyNr, n => s) 
        n+=1
    end
    n -=1
    demand = getDemand(scenarios) #gets energy demand
    wind = getWind(scenarios) #gets wind capacity
    probability = Dict()
    M = 1000000 #limit for transmission
    O = 1000000 #limit for
    for i in sKeys push!(probability, i => scenarios[i][2]) end #separates the probability from the scenario
    (available_transmissions,constants) = getTransmission(location)
    l = []
    for i in 1:11 for j in 1:11 if !haskey(available_transmissions,(i,j)) && !haskey(available_transmissions,(j,i)) push!(l, (i,j)) end  end end #creates network of available transmissions
    investment_cost = [114963.42,  235046.78	, 414140.92, 100761.61, 72041.15, 41020.57] #investment costs
    generation_cost = [0,15.63, 11.82, 23.17, 39.77, 58.70] #generation costs
    transmission_cost = 32 #transmission cost
    d5 = Model(Gurobi.Optimizer) #initialize model
    @variable(d5,x[1:11 , 1:6]>=0.0) #investment in each technologie in each country
    @variable(d5,g[1:11, 1:6 ,1:n]>=0.0) #production at each scenario
    @variable(d5,y[1:11 , 1:11],Bin) #decision to transmit
    @variable(d5,t[1:11, 1:11 ,1:n],upper_bound=10000,lower_bound=0) #transmission for each scenario
    @variable(d5,u[1:n, 1:11]>=0.0) #unmet demand of each scenario
    
    @constraint(d5,
        [i = 1:11, s = 1:n],
        (sum(g[i,k,s] for k in 1:6)
        + sum(t[j,i,s] for j in 1:11 if i != j) 
        - sum(t[i,j,s] for j in 1:11 if i != j)
        - demand[sKeyNr[s]][i] + u[s,i]) == 0
    ) #constraint that demands energy needs +production +- exports + unmet demand needs to equal zero 
    @constraint(d5,  sum(x[i,1] for i in 1:11)>= 0.32*sum(x[i,j] for j = 1:6 for i in 1:11)) #total renewable has to equal 32% of total production
    @constraint(d5, [i = 1:11, s = 1:n, j = 1:6] , x[i,j] >= g[i,j,s]) #capacity has to be greater than used 
    @constraint(d5, [i = 1:11, s = 1:n] ,*(wind[sKeyNr[s]][i],x[i,1]) >= g[i,1,s]) #renewable limit
    @constraint(d5, [q = l], y[q[1],q[2]] == 0) #sets transmissions beteween unconnected regions to zero
    @constraint(d5, [i = 1:11, j = 1:11, s = 1:n],t[i,j,s] <= *(M,y[i,j])) 
    @constraint(d5, [i=1:11,j=1:11], y[i,j] == y[j,i]) #transmissions to and from have to both be available/unavailable

    @objective(d5,Min,
       sum( *(x[i,j],investment_cost[j]) for j = 1:6 for i = 1:11) +
        sum(*(y[i[1],i[2]],*(available_transmissions[i],transmission_cost)) for i = keys(available_transmissions))+
        sum(*(probability[sKeyNr[s]],sum((*(g[i,j,s],generation_cost[j])) for i = 1:11 for j = 1:6) +
        sum(*(t[i,j,s],constants[3]) for i = 1:11 for j = 1:11) +
        sum(*(O,u[s,i]) for i = 1:11)) for s = 1:n)
    ) #minimization problem


    optimize!(d5) #optimizer
    o_value = JuMP.objective_value(d5,result = 1)
    x_value = JuMP.value.(x)
    y_value = JuMP.value.(y)
    t_value = JuMP.value.(t)
    g_value = JuMP.value.(g)
    u_value = JuMP.value.(u) #saves different results
    scenarios2 = samplingMethod(book,8760)
    demand2 = getDemand(scenarios2)
    wind2 = getWind(scenarios2)
    sumTech = zeros(11,6)
    sumTransmission = zeros(11,11)
    sumUnmet = zeros(11)
    o_value_2 = 0
    
    for s in keys(scenarios2) #solves for each scenario with fixed values in order to get a discretization error
        a = Model(Gurobi.Optimizer)

        @variable(a,x[1:11 , 1:6]) #investment in each technologie in each country
        @variable(a,g[1:11, 1:6]>=0.0) #production at each scenario
        @variable(a,y[1:11 , 1:11]) #decision to transmit
        @variable(a,t[1:11, 1:11],upper_bound=10000,lower_bound=0) #transmission for each scenario
        @variable(a,u[1:11]>=0.0) #unmet demand of each scenario

        for i in 1:11 for j in 1:6 JuMP.fix(x[i,j],x_value[i,j]) end end
        for i in 1:11 for j in 1:11 JuMP.fix(y[i,j],y_value[i,j]) end end


        @constraint(a,
            [i = 1:11],
            (sum(g[i,k] for k in 1:6)
            + sum(t[j,i] for j in 1:11 if i != j) 
            - sum(t[i,j] for j in 1:11 if i != j)
            - demand2[s][i] + u[i]) == 0
        )
        @constraint(a, [i = 1:11, j = 1:6] , x[i,j] >= g[i,j])
        @constraint(a, [i = 1:11] ,*(wind2[s][i],x[i,1]) >= g[i,1]) 
        @constraint(a, [i = 1:11, j = 1:11],t[i,j] <= *(M,y[i,j])) 
        @objective(a,Min,
            sum(*(x[i,j],investment_cost[j]) for j = 1:6 for i = 1:11) +
            sum(*(y[i[1],i[2]],*(available_transmissions[i],transmission_cost)) for i = keys(available_transmissions))+
            sum((*(g[i,j],generation_cost[j])) for i = 1:11 for j = 1:6) + sum(*(t[i,j],constants[3]) for i = 1:11 for j = 1:11) + sum(*(O,u[i]) for i = 1:11)
        )

        optimize!(a)
        g_value_2 = JuMP.value.(g)
        t_value_2 = JuMP.value.(t)
        u_value_2 = JuMP.value.(u)
        for i in 1:11 for j in 1:6 sumTech[i,j] += g_value_2[i,j]/8760 end end
        for i in 1:11 for j in 1:11 sumTransmission[i,j] += t_value_2[i,j]/8760 end end
        for i in 1:11 sumUnmet[i] += u_value_2[i]/8760 end
        o_value_2 +=  JuMP.objective_value(a,result = 1)/8760
    end
    print_matrix_2d(sumTech,11,6,"Print of average tech") #helper functions to present results
    print_matrix_2d(sumTransmission,11,11,"Print of average transmissions")
    println(sumUnmet)
    plotResult(x_value,t_value,y_value,g_value,u_value,n)
    println(o_value)
    println(o_value_2)
end



function print_matrix_2d(o,y,x,s)
    println("")
    println(s)
    println("")
    println("\\hline")
    m = zeros(11,11)
    for i in 1:y
        print("c"*string(i))
        for j in 1:x
            m[i,j] = o[i,j]
            print(" & ")
            print(round(o[i,j],digits=2))
        end
        println("\\\\")
        println("\\hline")
    end
    m
end

function average_3d(o,k,x,y)
    m = zeros(11,11)
    for i in 1:x
        for j in 1:y
            m[i,j] = sum(o[i,j,:])/k
        end
    end
    m
end

function std_3d(o,s,k,x,y)
    m = zeros(11,11)
    for i in 1:x
        for j in 1:y
            result = sum((o[i,j,t]-s[i,j])^2 for t in 1:k)
            m[i,j] = sqrt(result/k)
        end
    end
    m
end

function print_gas(x,avg,std)
println("")
print("Cap")
for i in 1:11
    print(" & ") 
    print(round(x[i,5],digits=2))
end
println("\\\\")
println("\\hline")
print("Avg")
for i in 1:11
    print(" & ") 
    print(round(avg[i,5],digits=2))
end
println("\\\\")
println("\\hline")
print("Std")
for i in 1:11
    print(" & ") 
    print(round(std[i,5],digits=2))
end
println("\\\\")
println("\\hline")
println("")
end

function plotResult(x,t,y,g,u,k)
    y2 = print_matrix_2d(y,11,11,"Print of available transmissions")
    m = average_3d(t,k,11,11)
    n = std_3d(t,m,k,11,11)
    print_matrix_2d(m,11,11,"Print of average transmissions")
    print_matrix_2d(n,11,11,"Print of std for transmissions")
    x2 = print_matrix_2d(x,11,6,"Print of created capacity")
    m = average_3d(g,k,11,6)
    n = std_3d(g,m,k,11,6)
    print_matrix_2d(m,11,6,"Print of average used capacity")
    print_matrix_2d(n,11,6,"Print of std for used capacity")
    print_gas(x2,m,n)
    graphplot(y2, names=string.(1:11), nodeshape=:circle,curvature_scalar=0.2,self_edge_size=4.5, nodesize = 0.5)
    savefig("Wasserstein")
end 

function testFunction()
   testScenario(50) 
   nothing
end





@test testFunction() === nothing



