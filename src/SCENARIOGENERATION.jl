module SCENARIOGENERATION
using Random
using Clustering
using LinearAlgebra

export sampler, sampling, kclusterMethod, wassersteinCall, samplingMethod

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

function searchsortednearest(a,x,n) 
    result = 0
    d = Inf
    for i in 1:n
        if norm((x-a[:,i]),2) < d
            d = norm(x-a[:,i],2)
            result = i
        end
    end
    result
 end

 #=
 function distanceBetweenPoints(dataset) #O time of n squared, problem
    distances = Dict()
    dkeys = keys(dataset)
    for i in dkeys
        for j in dkeys
            push!(distances,(i,j) => abs(dataset[i]-dataset[j]))
        end
    end
    distances
 end
 =#

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

function samplingMethod(dataset,samples)
    sample = sampling(dataset,samples)
    new_sample = Dict()
    for i in keys(sample)
        push!(new_sample ,i => (sample[i],1/samples))
    end
    new_sample
end

getType(s) = typeof(Float64.(1:length(s[2])))

"""Gives kcluster of input dataset using Clustering.jl"""
function kclusterMethod(dataset, samples) 
    n = length(dataset)
    w = length(popfirst!(collect(values(dataset))))
    result = Dict()
    m = zeros(w,n)
    t = 1
    keymap = Dict()
    for i in keys(dataset)
        push!(keymap, t => i)
        t+=1
    end
    for i in 1:n for j in 1:w m[j,i] = dataset[keymap[i]][j] end end
    means = kmeans(m,samples)
    centers = means.centers
    nr = means.counts
    for i in 1:samples
        center = searchsortednearest(m,centers[:,i],n) #returns closest real key.
        result[keymap[center]] = (dataset[keymap[center]],nr[i]/n)
    end
    result
end 

#elects whether to call the function with a predefined probability table or not.
wassersteinCall(dataset,samples,P,order) = (P ===  nothing) ?  wassersteinMethod(dataset,samples,createEqualProbability(dataset),order) : wassersteinMethod(dataset,samples,P,order) 

function createEqualProbability(dataset)
    result = Dict()
    for i in keys(dataset) 
        push!(result, i => 1/length(dataset))
    end
    result
end


takeSum(a,b) = sum(abs(a.-b))

distanceValue(a,b) = norm(a-b,1)
    
function wassersteinMethod(dataset,samples,P,order) 
    z = []
    d = []
    v = []
    push!(z,sampling(dataset,samples))
    distances = Dict()
    distanceFunc(a,b) = haskey(distances,(a,b)) ? distances[a,b] : (haskey(distances,(b,a)) ? distances[b,a] : push!(distances,(a,b)=> distanceValue(a,b))[a,b]) 
    probabilityFunc(a) = P[a]
    function inner(k1,d00)
        k = k1
        d0 = d00
        isTrue = true
        while isTrue
            push!(d,d0)
            push!(v, Dict())
            zkeys = keys(z[k])
            dkeys = keys(dataset)
            for i in dkeys
                current_min = Inf
                key = nothing
                for j in zkeys
                    if distanceFunc(i,j) < current_min
                        current_min = distanceFunc(i,j)
                        key = j
                    end
                end
                haskey(v[k],key) ? v[k][key] = push!(v[k][key],i) : v[k][key] = [i]
            end
            result = 0
            for i in zkeys
                if haskey(v[k],i)
                    for j in v[k][i]
                        result += *(P[j],(^(distanceFunc(i,j),order)))
                    end
                end 
            end
            z2 = Dict()
            temp = Inf
            key = nothing
            for i in keys(v[k])
                for j in v[k][i]
                    if temp > sum(order .^ distanceFunc.(v[k][i],j))  
                        temp = sum(order .^ distanceFunc.(v[k][i],j))
                        key = j
                    end
                end
                push!(z2, key => dataset[key])
                temp = Inf
                key = nothing
            end
            push!(z,z2)
            isTrue = result < d[k]
            k = k+1
            d0 = result
            #result < d[k] ? inner(k+1,result) : (z[k-1] , v[k-1])
        end
        (z[k-1],v[k-1])
    end
    (output,probability) = inner(1,Inf)
    final = Dict()
    for i in keys(output)
        push!(final,i => (output[i], sum(probabilityFunc.(probability[i]))))
    end
    final
end

end


