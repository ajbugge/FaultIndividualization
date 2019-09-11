%%
%Autor: Aina Juell Bugge
%email: aina.juell.bugge@gmail.com

% code for the paper: "Bugge, A. J., S. R. Clark, J. E. Lie, and J. I. Faleide, 2018, A case study on semiautomatic seismic
%interpretation of unconformities and faults in the southwestern Barents Sea: Interpretation, 6, SD29-SD40"

%%
[segy,SegyTraceHeader,SegyHeader]=ReadSegyConstantTraceLength('filename.sgy');
il=unique([SegyTraceHeader.Inline3D]); %count number of xlines
xl=unique([SegyTraceHeader.Crossline3D]); %count number of xlines
samples=[SegyHeader.ns];
lines=length(il)*length(xl);
segy(samples, lines)=0; %pad with empty zero-pixels
fault_data=reshape(segy, [samples length(xl) length(il)]); %transform to a 3D matrix of [timeslices, xl, il]
%%
% Fault_data should be a binary representation of a fault attribute, e.g. fault likelihood (Hale, 2013)
F=fault_data;
F(F > 0.) = 1; 
F(F < 0) = 0; 

%% 
Area_filter_criterion=1000;
Length_filter_criterion=100;
Filter_criterion_2D=1;
%%
F=bwareaopen(F, Area_filter_criterion);   
O1=zeros(samples, xl, il);
for s=1:samples
    slide=squeeze(F(s,:,:));
    slide=bwmorph(slide,'thin', inf);
    slide=bwareaopen(slide, Filter_criterion_2D); 
    B=bwmorph(slide, 'branchpoints');
    B=bwmorph(B, 'thick');
    new= slide-B;
    new(new < 0) = 0; 
    O1(s,:,:)=new;
end 

%% Separate binary objects into dip cubes
for s=1:xl
    slide=squeeze(O1(:,s,:));
    slide=bwareaopen(slide,Filter_criterion_2D);
    L=labelmatrix(bwconncomp(slide));
    ori=regionprops(L, 'orientation'); 
    deg_range1=( [ori.Orientation] > 0 & [ori.Orientation] < 90); 
    IM1 = ismember(L,find(deg_range1)); 
    deg_range2=( [ori.Orientation] > -90 & [ori.Orientation] < 0); 
    IM2 = ismember(L,find(deg_range2)); 
    pos_dip(:,s,:)=IM1;  
    neg_dip(:,s,:)=IM2;
end

%% 3D area filtering
filteredPcube=bwareaopen(pos_dip, Area_filter_criterion);
filteredNcube=bwareaopen(neg_dip, Area_filter_criterion);

%% filter on length and extract individual faults
both={filteredNcube filteredPcube};
for j=1:2   
    cube=both{j};
    cc=bwconncomp(cube);
    L=labelmatrix(cc); 
    MAL= regionprops3(L, 'MajorAxisLength');   
    idx = find([MAL.MajorAxisLength] > Length_filter_criterion); 
    filtered_OrientationCube = ismember(L, idx);    
    FilterCube{j}=filtered_OrientationCube;
    cc2=bwconncomp(filtered_OrientationCube);
    L=labelmatrix(cc2);
    for h=1:cc2.NumObjects
            fault=L==h;
            all_faults{j,h}=fault;
    end
    disp(h);
end

%% store all faults in cell 'AF' and in a cube 'filteredFC'
Individual_faults=all_faults;
Individual_faults=reshape(Individual_faults, 1, numel(Individual_faults));
Individual_faults(cellfun(@isempty, Individual_faults))=[];  %reshape and remove blanks
labelledFaultCube=zeros([samples length(xl) length(il)]);
for q=1:length(Individual_faults)
    fault=Individual_faults{q}; 
    newfault=fault*q;
    labelledFaultCube=labelledFaultCube+newfault;
end
% Individual_faults stores each fault surface as a 3D matrix, while
% labelledFaultCube is a cube with all extracted faults labelled with individual
% numbers.

%%
figure;
imagesc(squeeze(labelledFaultCube(:,50,:)))
figure;
imagesc(squeeze(labelledFaultCube(:,:,50)))

