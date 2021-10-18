module SCENARIOGENERATION
using Random
using Clustering

export sampler, sampling, kclusterMethod, wassersteinCall

""""finds the value closest to x in a"""
#=function searchsortednearest(a,x) 
    b = sort(a)
    i = searchsortedfirst(b,x) #Julia function that finds first value in a larger than x
    if (i==1); return b[i]; end #no smaller value, returns the smallest value in a
    if (i>length(b)); return b[length(b)]; end #no larger value, returns the largest value in a
    if (b[i]==x); return b[i]; end #exact match, return a[i] = x
    if (abs(b[i]-x) < abs(b[i-1]-x)) #compares difference between a[i] and a[i-1] as x lies between them and returns the closer one.
       return b[i]
    else
       return b[i-1]
    end
 end =#

 function searchsortednearest(a,x) 
    result = Dict()
    d = Inf
    akeys = keys(a)
    for i in akeys
        if(abs(x-a[i])<d)
            d = abs(x-a[i])
            result = i
        end
    end
    println(result)
    result
 end

 function distanceBetweenPoints(dataset)
    distances = Dict()
    dkeys = keys(dataset)
    for i in dkeys
        for j in dkeys
            push!(distances,(i,j) => abs(dataset[i]-dataset[j]))
        end
    end
    distances
 end
 

"""Random Sampler v$(1) using Random.jl function"""
sampler(dataset, samples) = rand(dataset,samples)    #Takes random input as vector v and return sample of size n, part of Random.jl package.

"""Alternative sampler"""
function sampling(dataset,samples) 
    sample_list = Dict()
    binary_list = shuffle(hcat(zeros(Int64,1,length(dataset)-samples),ones(Int64,1,samples)))
    j=1
    for i in dataset 
        if((binary_list[j]) > 0) push!(sample_list,i) end 
        j+=1
    end
    sample_list
end


"""Gives kcluster of input dataset using Clustering.jl"""
function kclusterMethod(dataset, samples) 
    result = Dict()
    #new_dataset = sampling(dataset,samples)
    centers = (kmeans(reshape(collect(values(dataset)),1,length(dataset)),samples)).centers
    for i in centers
        center = searchsortednearest(dataset,i) #returns closest real key.
        result[center] = dataset[center]
    end
    result
end 

wassersteinCall(dataset,samples,P,order) = (P ===  nothing) ?  wassersteinMethod(dataset,samples,createEqualProbability(dataset),order) : wassersteinMethod(dataset,samples,P,order) 

function createEqualProbability(dataset)
    result = Dict()
    for i in keys(dataset) 
        push!(result, i => 1/length(dataset))
    end
    result
end

takeSum(a,b) = sum(abs(a.-b))
    
function wassersteinMethod(dataset,samples,P,order) 
    z = []
    d = []
    v = []
    push!(z,sampling(dataset,samples))
    distances = distanceBetweenPoints(dataset)
    distanceFunc(a,b) = distances[(a,b)]
    probabilityFunc(a) = P[a]
    function inner(k,d0)
        push!(d,d0)
        push!(v, Dict())
        zkeys = keys(z[k])
        dkeys = keys(dataset)
        for i in dkeys
            current_min = Inf
            key = nothing
            for j in zkeys
                if distances[(i,j)] < current_min
                    current_min = distances[(i,j)]
                    key = j
                end
            end
            haskey(v[k],key) ? v[k][key] = push!(v[k][key],i) : v[k][key] = [i]
        end
        result = 0
        for i in zkeys
            if haskey(v[k],i)
                for j in v[k][i]
                    result += *(P[j],(^(abs(dataset[j]-z[k][i]),order)))
                end
            end 
        end
        z2 = Dict()
        temp = Inf
        key = nothing
        for i in keys(v[k])
            for j in dkeys
                if temp > sum(distanceFunc.(v[k][i],j))  
                    temp = sum(distanceFunc.(v[k][i],j))
                    key = j
                end
            end
            push!(z2, key => dataset[key])
            temp = Inf
            key = nothing
        end
        push!(z,z2)
        result < d[k] ? inner(k+1,result) : (z[k-1] , v[k-1])
    end
    (output,probability) = inner(1,Inf)
    final = Dict()
    for i in keys(output)
        push!(final,i => (output[i], sum(probabilityFunc.(probability[i]))))
    end
    final
end

end
