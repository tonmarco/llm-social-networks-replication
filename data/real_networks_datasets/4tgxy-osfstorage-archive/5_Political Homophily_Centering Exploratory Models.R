###### Packages #####
library(haven)
library(tidyverse)
library(summarytools)

#####Load data#####
rm(list=ls()) #clear the environment
Data <- read_sav("PEAS_T1_RAW_1.sav")

#####Data Cleaning/Mutation#####

IM <- c("PA1R", "PA4")
RWAN <- c("RWAA1", "RWAA2", "RWAC1", "RWAC2", "RWAT1", "RWAT2")
RWAAN <- c("RWAA1", "RWAA2")
RWATN <- c("RWAT1", "RWAT2")
PATN <- c("PAT1", "PAT2", "PAT3", "PAT4")

Data <- Data  %>% mutate(PA1R = 6-PA1) %>% 
  mutate(
    IMM = rowMeans(select(., IM)),
    RWA = rowMeans(select(., RWAN)),
    PAT = rowMeans(select(., PATN)),
    RWAA = rowMeans(select(., RWAAN)),
    RWAT = rowMeans(select(., RWATN)),
  )

##### Rearrange data to compute max diff and SD of Political attitudes #####

mb <- Data %>% select(ID, RWA, RWAA, RWAT, IMM, PAT)
m1 <- Data %>% select(ID, PEER_1)
m2 <- Data %>% select(ID, PEER_2)
m3 <- Data %>% select(ID, PEER_3)
m4 <- Data %>% select(ID, PEER_4)
m5 <- Data %>% select(ID, PEER_5)
m6 <- Data %>% select(ID, PEER_6)
m7 <- Data %>% select(ID, PEER_7)

j1 <- left_join(m1, mb, by = c("PEER_1" = "ID")) %>% 
  rename(RWA_P1 = RWA,
         RWAT_P1 = RWAT,
         RWAA_P1 = RWAA,
         IMM_P1 = IMM,
         PAT_P1 = PAT)

j2 <- left_join(m2, mb, by = c("PEER_2" = "ID")) %>% 
  rename(RWA_P2 = RWA,
         RWAT_P2 = RWAT,
         RWAA_P2 = RWAA,
         IMM_P2 = IMM,
         PAT_P2 = PAT)

j3 <- left_join(m3, mb, by = c("PEER_3" = "ID")) %>% 
  rename(RWA_P3 = RWA,
         RWAT_P3 = RWAT,
         RWAA_P3 = RWAA,
         IMM_P3 = IMM,
         PAT_P3 = PAT)

j4 <- left_join(m4, mb, by = c("PEER_4" = "ID")) %>% 
  rename(RWA_P4 = RWA,
         RWAT_P4 = RWAT,
         RWAA_P4 = RWAA,
         IMM_P4 = IMM,
         PAT_P4 = PAT)

j5 <- left_join(m5, mb, by = c("PEER_5" = "ID")) %>% 
  rename(RWA_P5 = RWA,
         RWAT_P5 = RWAT,
         RWAA_P5 = RWAA,
         IMM_P5 = IMM,
         PAT_P5 = PAT)

j6 <- left_join(m6, mb, by = c("PEER_6" = "ID")) %>% 
  rename(RWA_P6 = RWA,
         RWAT_P6 = RWAT,
         RWAA_P6 = RWAA,
         IMM_P6 = IMM,
         PAT_P6 = PAT)

j7 <- left_join(m7, mb, by = c("PEER_7" = "ID")) %>% 
  rename(RWA_P7 = RWA,
         RWAT_P7 = RWAT,
         RWAA_P7 = RWAA,
         IMM_P7 = IMM,
         PAT_P7 = PAT)

D1 <- left_join(j1, j2, by="ID") %>% 
  left_join(., j3, by="ID") %>% 
  left_join(., j4, by="ID") %>%
  left_join(., j5, by="ID") %>%
  left_join(., j6, by="ID") %>%
  left_join(., j7, by="ID") 

rcol <- c("RWA_P1", "RWA_P2", "RWA_P3", "RWA_P4", "RWA_P5", "RWA_P6", "RWA_P7")
rcol2 <- c("RWAA_P1", "RWAA_P2", "RWAA_P3", "RWAA_P4", "RWAA_P5", "RWAA_P6", "RWAA_P7")
rcol3 <- c("RWAT_P1", "RWAT_P2", "RWAT_P3", "RWAT_P4", "RWAT_P5", "RWAT_P6", "RWAT_P7")
icol <- c("IMM_P1", "IMM_P2", "IMM_P3", "IMM_P4", "IMM_P5", "IMM_P6", "IMM_P7")
pcol <- c("PAT_P1", "PAT_P2", "PAT_P3", "PAT_P4", "PAT_P5", "PAT_P6", "PAT_P7")

D1$RWA_MEAN <-   apply(D1[,rcol], 1, mean, na.rm=TRUE) #calculate SDs for PEERS RWA.  
D1$PAT_MEAN <-   apply(D1[,pcol], 1, mean, na.rm=TRUE) #calculate SDs for PEERS RWA.  
D1$IMM_MEAN <-   apply(D1[,icol], 1, mean, na.rm=TRUE) #calculate SDs for PEERS RWA.  
D1$RWAA_MEAN <-   apply(D1[,rcol2], 1, mean, na.rm=TRUE) #calculate SDs for PEERS RWA.  
D1$RWAT_MEAN <-   apply(D1[,rcol3], 1, mean, na.rm=TRUE) #calculate SDs for PEERS RWA.  

Data_Full <- left_join(Data, D1, by = "ID") #rejoin the data

Data_Full <- Data_Full %>% mutate(RWA_Peer_Diff = abs(RWA_MEAN-mean(na.omit(RWA))),
                                  RWA_GM_Diff = abs(RWA-mean(na.omit(RWA))),
                                  PAT_Peer_Diff = abs(PAT_MEAN-mean(na.omit(PAT))),
                                  PAT_GM_Diff = abs(PAT-mean(na.omit(PAT))),
                                  IMM_Peer_Diff = abs(IMM_MEAN-mean(na.omit(IMM))),
                                  IMM_GM_Diff = abs(IMM-mean(na.omit(IMM))),
                                  RWAA_Peer_Diff = abs(RWAA_MEAN-mean(na.omit(RWAA))),
                                  RWAA_GM_Diff = abs(RWAA-mean(na.omit(RWAA))),
                                  RWAT_Peer_Diff = abs(RWAT_MEAN-mean(na.omit(RWAT))),
                                  RWAT_GM_Diff = abs(RWAT-mean(na.omit(RWAT))))

#####Graphing RWA
labels <- c("RWA_Peer_Diff", "RWA_GM_Diff")
rwat  <- Data_Full %>% 
  gather(KEY, score, labels)

rwat$KEY[rwat$KEY == "RWA_Peer_Diff"] <- "Peer-Mean Differences"
rwat$KEY[rwat$KEY == "RWA_GM_Diff"] <- "Grand-Mean Differences"

figure_1 <- ggstatsplot::ggwithinstats(
  data = rwat,
  x = KEY,
  y = score,
  xlab="Group Difference",
  ylab="Absolute Difference in RWA",
  title = "RWA Grand-Mean and Peer-Mean Difference Comparisons",
  mean.path.args = list(size=2, alpha=.5),
  point.path = FALSE,
  package="yarrr",
  palette="info2"
) +
  theme_classic() +
  theme(legend.position = "none",
#        text = element_text(size=15),
        axis.title.x = element_text(margin = unit(c(5, 0, 0, 0), "mm")),
        axis.title.y = element_text(margin = unit(c(0, 5, 0, 0), "mm"))
  )


##GRAPHING PAT####
labels2 <- c("PAT_Peer_Diff", "PAT_GM_Diff")

pt  <- Data_Full %>% 
  gather(KEY, score, labels2) 

pt$KEY[pt$KEY == "PAT_Peer_Diff"] <- "Peer-Mean Differences"
pt$KEY[pt$KEY == "PAT_GM_Diff"] <- "Grand-Mean Differences"

figure_2 <- ggstatsplot::ggwithinstats(
  data = pt,
  x = KEY,
  y = score,
  xlab="Group Difference",
  ylab="Absolute Difference in Patriotism",
  title = "Patriotism Grand-Mean and Peer-Mean Difference Comparisons",
  mean.path.args = list(size=2, alpha=.5),
  point.path = FALSE,
  package="yarrr",
  palette="info2"
) +
  theme_classic() +
  theme(legend.position = "none",
 #       text = element_text(size=15),
    axis.title.x = element_text(margin = unit(c(5, 0, 0, 0), "mm")),
    axis.title.y = element_text(margin = unit(c(0, 5, 0, 0), "mm"))
  )



##GRAPHING IMM
labels3 <- c("IMM_Peer_Diff", "IMM_GM_Diff")

tr  <- Data_Full %>% 
  gather(KEY, score, labels3) 

tr$KEY[tr$KEY == "IMM_Peer_Diff"] <- "Peer-Mean Differences"
tr$KEY[tr$KEY == "IMM_GM_Diff"] <- "Grand-Mean Differences"

figure_3 <- ggstatsplot::ggwithinstats(
  data = tr,
  x = KEY,
  y = score,
  xlab="Group Difference",
  ylab="Absolute Difference in Anti-Immigration Attitudes",
  title = "Anti-Immigration Grand-Mean and Peer-Mean Difference Comparisons",
  mean.path.args = list(size=2, alpha=.5),
  point.path = FALSE,
  package="yarrr",
  palette="info2"
) +
  theme_classic() +
  theme(legend.position = "none",
#        text = element_text(size=15),
        axis.title.x = element_text(margin = unit(c(5, 0, 0, 0), "mm")),
        axis.title.y = element_text(margin = unit(c(0, 5, 0, 0), "mm"))
  )

#####Graphing RWAA
labels <- c("RWAA_Peer_Diff", "RWAA_GM_Diff")
rwat2  <- Data_Full %>% 
  gather(KEY, score, labels)

rwat2$KEY[rwat2$KEY == "RWAA_Peer_Diff"] <- "Peer-Mean Differences"
rwat2$KEY[rwat2$KEY == "RWAA_GM_Diff"] <- "Grand-Mean Differences"

figure_4 <- ggstatsplot::ggwithinstats(
  data = rwat2,
  x = KEY,
  y = score,
  xlab="Group Difference",
  ylab="Absolute Difference in RWA-Authoritarianism",
  title = "RWA Authoritarianism Grand-Mean and Peer-Mean Difference Comparisons",
  mean.path.args = list(size=2, alpha=.5),
  point.path = FALSE,
  package="yarrr",
  palette="info2"
) +
  theme_classic() +
  theme(legend.position = "none",
        #        text = element_text(size=15),
        axis.title.x = element_text(margin = unit(c(5, 0, 0, 0), "mm")),
        axis.title.y = element_text(margin = unit(c(0, 5, 0, 0), "mm"))
  )

#####Graphing RWAT
labels <- c("RWAT_Peer_Diff", "RWAT_GM_Diff")
rwat3  <- Data_Full %>% 
  gather(KEY, score, labels)

rwat3$KEY[rwat3$KEY == "RWAA_Peer_Diff"] <- "Peer-Mean Differences"
rwat3$KEY[rwat3$KEY == "RWAA_GM_Diff"] <- "Grand-Mean Differences"

figure_5 <- ggstatsplot::ggwithinstats(
  data = rwat3,
  x = KEY,
  y = score,
  xlab="Group Difference",
  ylab="Absolute Difference in RWA-Traditionalism",
  title = "RWA Traditionalism Grand-Mean and Peer-Mean Difference Comparisons",
  mean.path.args = list(size=2, alpha=.5),
  point.path = FALSE,
  package="yarrr",
  palette="info2"
) +
  theme_classic() +
  theme(legend.position = "none",
        #        text = element_text(size=15),
        axis.title.x = element_text(margin = unit(c(5, 0, 0, 0), "mm")),
        axis.title.y = element_text(margin = unit(c(0, 5, 0, 0), "mm"))
  )


plotrow <-cowplot::plot_grid(figure_1, figure_2, figure_3, figure_4, figure_5, labels=c("A", "B", "C", "D", "E"), nrow=2)
cowplot::save_plot("plotx.pdf", plotrow, base_width=20, base_height = 12)


plotrow2 <-cowplot::plot_grid(figure_4, figure_5, labels=c("A", "B"), nrow=1)
cowplot::save_plot("plotx_2.png", plotrow2, base_width=20, base_height = 6)

