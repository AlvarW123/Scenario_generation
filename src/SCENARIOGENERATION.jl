module SCENARIOGENERATION
using Random
using Clustering

export sampler, sampling, kcluster

""""finds the value closest to x in a"""
function searchsortednearest(a,x) 
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
 end
 

"""Random Sampler v$(1) using Random.jl function"""
sampler(dataset, samples) = rand(dataset,samples)    #Takes random input as vector v and return sample of size n, part of Random.jl package.

"""Alternative sampler"""
function sampling(dataset,samples) 
    sample_list = Float64[]
    binary_list = shuffle(vcat(zeros(Int64,1,size(dataset,1)-samples),ones(Int64,1,samples)))
    for i in 1:size(dataset,1) 
        if((binary_list[i]) > 0) push!(sample_list,dataset[i]) end 
    end
    sample_list
end


"""Gives mean of kcluster of input dataset using Clustering.jl"""
function kcluster(dataset, samples) 
    result = []
    centers = (kmeans(reshape(dataset,1,length(dataset)),samples)).centers
    for i in centers
        push!(result,searchsortednearest(dataset,i))
    end
    result
end 

 

end
