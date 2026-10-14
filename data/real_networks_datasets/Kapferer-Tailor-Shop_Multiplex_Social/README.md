

# KAPFERER-TAILOR-SHOP MULTIPLEX NETWORK

###### Last update: 1 July 2014

### Reference and Acknowledgments

This README file accompanies the dataset representing the multiplex social network in a tailor shop.
If you use this dataset in your work either for analysis or for visualization, you should acknowledge/cite the following book:
	
	"Strategy and transaction in an African factory" 
	Kapferer B. (1972)
	Manchester: Manchester University Press
	


### Description of the dataset

Interactions in a tailor shop in Zambia (then Northern Rhodesia) over a period of ten months. 

Layers represent two different types of interaction, recorded at two different times (seven months apart) over a period of one month. TI1 and TI2 record the "instrumental" (work- and assistance-related) interactions at the two times; TS1 and TS2 the "sociational" (friendship, socioemotional) interactions.

The data are particularly interesting since an abortive strike occurred after the first set of observations, and a successful strike took place after the second.

There are 39 nodes in total, labelled with integer ID between 1 and 39, with 1018 connections.
The multiplex is directed and unweighted, stored as edges list in the file
    
    Kapferer-Tailor-Shop_multiplex.edges

with format

    layerID nodeID nodeID weight

(Note: all weights are set to 1)

The IDs of all layers are stored in 

    Kapferer-Tailor-Shop_layers.txt

The IDs of nodes and their label can be found in the file

    Kapferer-Tailor-Shop_nodes.txt



### License

The KAPFERER-TAILOR-SHOP MULTIPLEX DATASET is provided "as is" and without warranties as to performance or quality or any other warranties whether expressed or implied. 

