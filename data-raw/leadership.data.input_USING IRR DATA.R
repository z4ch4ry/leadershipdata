## Import all data into data frames and recode as necessary

library(tidyverse)
library(tidytext)
library(textstem)
library(hunspell)
library(car)
library(reshape2)
library(stats)
library(devtools)
library(roxygen2)
library(readr)
library(readxl)
library(tidylog)

####IMPORTING DATA SETS

#d<-read.csv("zg_leadership3.csv")
d<-read.csv("data-raw/ehraf_leadership_TOTAL_FINAL_IRR.csv")
d<-d[c(1:1212),]

# Incorporating SCCS label, variables -------------------------------------

load('data-raw/sccs.RData')
sccs = as.data.frame(sccs)
# ID's of SCCS cultures that correspond to HRAF probability sample cultures
sccs.nums=c(19,37,79,172,28,7,140,76,121,109,124,24,87,12,69,181,26,51,149,85,112,125,16,94,138,116,158,57,102,4,34,182,13,127,52,62,165,48,42,36,113,152,100,16,132,98,167,154,21,120)

## adding variables SCCS variables
sccs.vars=c('SOCNAME','V61','V63', 'V64', 'V69','V70', 'V73', 'V76', 'V77',  'V79',
            'V80', 'V81', 'V83', 'V84', 'V85', 'V93', 'V94', 'V156', 'V158', 'V158.1',
            'V207', 'V208', 'V210', 'V234', 'V235', 'V236', 'V247', 'V270', 'V276',
            'V573', 'V574', 'V575', 'V587', 'V666', 'V669', 'V670', 'V679',
            'V756', 'V758', 'V759', 'V760', 'V761', 'V762', 'V763', 'V764', 'V765', 'V766', 'V767',
            'V768', 'V769', 'V770', 'V773', 'V774', 'V775', 'V777', 'V778', 'V780', 'V785', 'V793', 'V794',
            'V795', 'V796', 'V835', 'V836', 'V860', 'V866', 'V867', 'V868', 'V869', 'V902', 'V903', 'V905',
            'V907', 'V910', 'V1133', 'V1134', 'V1648', 'V1683', 'V1684', 'V1685')

sccs.2 <- sccs[sccs.nums,sccs.vars]
Culture.codes <- read.delim("data-raw/Culture codes.txt")

Culture.codes$SCCS = as.character(Culture.codes$SCCS)
sccs.2 = merge(sccs.2, Culture.codes, by.x='row.names', by.y='SCCS')
cultures <- read.delim("data-raw/cultures.txt")
cultures = merge(cultures, sccs.2, by='Culture.code', all=T)
rm(sccs.2)

##d uses "c_culture_code", cultures uses "Culture.code" -- only two differences, e.g. two groups in PSF not in SCCS
cultures$c_culture_code<-cultures$Culture.code


## Isolating variables for MA focus
## Prestige/Dominance variables, VV variables, Neel variables (*d3 is main extract level data frame
##ORIGINAL CODE#d3 = d[,c(1:12, 27:35, 51:54, 61:67, 79:80)]

#d3<-d[,c(1:12,27:35,68,69,66,67,74:80,57,58)]


# Rows that are all zero on study variables == 1
# a=0
# for (i in 1:nrow(d3)){a[i] = 1*(sum(abs(d3[i,14:34]))==0)}
# d3$all.zero = a
# d4 = d3[d3$all.zero!=1,]

d$c_cultural_complexity <-as.numeric(d$c_cultural_complexity)

## Recode 0 to -1, and -1 to 0
tmp = as.matrix(d[,14:37])
tmp[tmp==0] = -2
tmp[tmp==-1] = 0
tmp[tmp==-2] = -1
d[,14:37] = tmp
rm(tmp)


##Culture level data

# Try to replicate d.ct in R
# PSF has Bahia Brazilians, but no leadership extracts from that culture, so delete that row

d.ct <-
  read.csv('data-raw/culture_fmpro2.csv', stringsAsFactors=F) %>%
  filter(c_name != 'Bahia Brazilians ') %>%  # Not in d
  left_join(as.data.frame(table(d$c_name), stringsAsFactors = F), by=c('c_name'='Var1')) %>%
  rename(extract_count = Freq)

# This function calculates the total +1, 0, or -1 for a set of model vars (e.g., neel_vars) for each culture (on d3)
# Set 'vars' to the model variables and val to +1, 0, or -1

# The problem with this is that it assumes d3 and d.ct have both been sorted by c_name
# model_total = function(vars, val){
#   as.numeric(by(d3[,vars], d3$c_name, FUN=function(x){sum(x==val, na.rm=T)}))
# }

model_total = function(vars, val, var_name){
  x = by(d[,vars], d$c_name, FUN=function(x){sum(x==val, na.rm=T)})
  y = data.frame(c_name=names(x), var_name=as.numeric(x))
  names(y) = c('c_name', var_name)
  return(y)
}

all_totals = function(vars, prefix){
  d.ct[paste(prefix, '_total_cell_count', sep='')] = d.ct$extract_count * length(vars)
  d.ct = left_join(d.ct, model_total(vars, 1, paste(prefix, '_total_for', sep='')))
  d.ct = left_join(d.ct, model_total(vars, 0, paste(prefix, '_total_none', sep='')))
  d.ct = left_join(d.ct, model_total(vars, -1, paste(prefix, '_total_against', sep='')))
}

# Neel vars
neel_vars = c('neel_better.mates','neel_big.family', 'neel_intelligence', 'neel_polygynous')
d.ct = all_totals(neel_vars, 'neel')

# Prestige vars
prest_vars = c('prestige_counsel','prestige_emulated', 'prestige_expertise', 'prestige_family', 'prestige_f.exp.success', 'prestige_likable', 'prestige_respected')
d.ct = all_totals(prest_vars, 'prest')

# Dominance vars
dom_vars = c('dom_aggression','dom_assert.authority', 'dom_avoid.dom', 'dom_fear', 'dom_fighting', 'dom_personality', 'dom_reputation', 'dom_strong')
d.ct = all_totals(dom_vars, 'dom')

#Hooper vars
hooper_vars = c('hooper_performance','hooper_sanction.freeriders','hooper_payoff','hooper_group.size','hooper_coop.activities')
d.ct = all_totals(hooper_vars, 'hooper')
# # Van Vugt vars
# vv_vars = c('vanvugt_coordinating', 'vanvugt_strategic')
# d.ct = all_totals('vanvugt_coordinating', 'vvcoord')
# d.ct = all_totals('vanvugt_strategic', 'vvstrat')

all_vars= c(neel_vars, prest_vars, dom_vars, hooper_vars)

## creating cumulative distriubtion table variables
d$evidence_prestige_for = (rowSums(d[,prest_vars]==1))
d$evidence_prestige_against = (rowSums(d[,prest_vars]==-1))
d$evidence_dom_for = (rowSums(d[,dom_vars]==1))
d$evidence_dom_against = (rowSums(d[,dom_vars]==-1))
d$evidence_neel_for = (rowSums(d[,neel_vars]==1))
d$evidence_neel_against = (rowSums(d[,neel_vars]==-1))
d$evidence_hooper_for = (rowSums(d[,hooper_vars]==1))
d$evidence_hooper_against = (rowSums(d[,hooper_vars]==-1))

# d$evidence_vv_for = (rowSums(d[,vv_vars]==1))
# d$evidence_vv_against = (rowSums(d[,vv_vars]==-1))

# # dplyr version (incomplete)
#
# d.ct.new2 = d %>%
#   group_by(c_name) %>%
#   summarise(
#     extract_count = n(),
#     neel_total_cell_count = n() * length(neel_vars),
#     neel_total_for = sum((neel_better.mates==1) + (neel_big.family==1) + (neel_intelligence==1) + (neel_polygynous==1)),
#     neel_total_none = sum((neel_better.mates==0) + (neel_big.family==0) + (neel_intelligence==0) + (neel_polygynous==0)),
#     neel_total_against = sum((neel_better.mates==-1) + (neel_big.family==-1) + (neel_intelligence==-1) + (neel_polygynous==-1))
#   )

## data set of all important culture level variables (*d.ct is main culture level data with model scores and model level variables)
# d.ct.old <-read.csv("cultures.totals.csv")
# d.ct.old$c_cultural_complexity <-as.numeric(d.ct$c_cultural_complexity)
#
# # Check d.ct against d.ct.old
# sum(d.ct$neel_total_for==d.ct.old$neel_total_for)/nrow(d.ct)
# sum(d.ct$neel_total_against==d.ct.old$neel_total_against)/nrow(d.ct)
#
# sum(d.ct$prest_total_for==d.ct.old$prest_total_for)/nrow(d.ct)
# sum(d.ct$prest_total_against==d.ct.old$prest_total_against)/nrow(d.ct)
#
# sum(d.ct$dom_total_for==d.ct.old$dom_total_for)/nrow(d.ct)
# sum(d.ct$dom_total_against==d.ct.old$dom_total_against)/nrow(d.ct)


## making data set of model totals by subsistence type - include total for, total against for each model (*d.sub is subsistence level, not used in main analyses)
d.sub <-read.csv("data-raw/d.sub_by_model_totals.csv")

##Creating data set of variable list with proportions (*d.prop is list of proportions at model level for extracts)
d.prop <-read.csv("data-raw/d.prop.csv")

##Merging cultures data with d.ct

d.ct=merge(cultures, d.ct, by='c_culture_code', all=T)



####RECODING / MANAGING VARIABLES

## Doing some recoding of subsistence level
d$subsistence2<-car::recode(d$c_subsistence_type, "'forager/food producers'= 'hunter gatherers'; 'foragers'='hunter gatherers';'horticulturalists'='horticulturalists'; 'intensive agriculturalists'='agriculturalists';'other'='other';'pastoral/agriculturalists'='pastoralists';'pastoralists'='pastoralists'")
d.ct$subsistence2<-car::recode(d.ct$c_subsistence_type, "'forager/food producers'= 'hunter gatherers'; 'foragers'='hunter gatherers';'horticulturalists'='horticulturalists'; 'intensive agriculturalists'='agriculturalists';'other'='other';'pastoral/agriculturalists'='pastoralists';'pastoralists'='pastoralists'")
#d.ct.old$subsistence2<-recode(d.ct.old$c_subsistence_type, "'forager/food producers'= 'hunter gatherers'; 'foragers'='hunter gatherers';'horticulturalists'='horticulturalists'; 'intensive agriculturalists'='agriculturalists';'other'='other';'pastoral/agriculturalists'='pastoralists';'pastoralists'='pastoralists'")


d$region2<-car::recode(d$c_subregion, "'Amazon and Orinoco'='South America'; 'Arctic and Subarctic'='North America'; 'Australia'='Insular Pacific'; 'British Isles'='Circum-Mediterranean';
                   'Central Africa'= 'Africa'; 'Central America'='South America'; 'Central Andes'='South America'; 'East Asia'='East Eurasia'; 'Eastern Africa'='Circum-Mediterranean';
                   'Eastern South America'='South America'; 'Eastern Woodlands'='North America'; 'Maya Area'='North America'; 'Melanesia'='Insular Pacific'; 'Micronesia'='Insular Pacific';
                   'Middle East'='Circum-Mediterranean'; 'North Asia'='East Eurasia'; 'Northern Africa'='Africa'; 'Northern Mexico'='North America';
                   'Northwest Coast and California'='North America'; 'Northwestern South America'='South America'; 'Plains and Plateau'='North America';
                   'Polynesia'='Insular Pacific'; 'Scandinavia'='Circum-Mediterranean'; 'South Asia'='East Eurasia'; 'Southeast Asia'='Insular Pacific';
                   'Southeastern Europe'='Circum-Mediterranean'; 'Southern Africa'='Africa'; 'Southern South America'='South America'; 'Southwest and Basin'= 'North America'; 'Western Africa'='Africa'")

d.ct$region2<-car::recode(d.ct$c_subregion, "'Amazon and Orinoco'='South America'; 'Arctic and Subarctic'='North America'; 'Australia'='Insular Pacific'; 'British Isles'='Circum-Mediterranean';
                     'Central Africa'= 'Africa'; 'Central America'='South America'; 'Central Andes'='South America'; 'East Asia'='East Eurasia'; 'Eastern Africa'='Circum-Mediterranean';
                     'Eastern South America'='South America'; 'Eastern Woodlands'='North America'; 'Maya Area'='North America'; 'Melanesia'='Insular Pacific'; 'Micronesia'='Insular Pacific';
                     'Middle East'='Circum-Mediterranean'; 'North Asia'='East Eurasia'; 'Northern Africa'='Africa'; 'Northern Mexico'='North America';
                     'Northwest Coast and California'='North America'; 'Northwestern South America'='South America'; 'Plains and Plateau'='North America';
                     'Polynesia'='Insular Pacific'; 'Scandinavia'='Circum-Mediterranean'; 'South Asia'='East Eurasia'; 'Southeast Asia'='Insular Pacific';
                     'Southeastern Europe'='Circum-Mediterranean'; 'Southern Africa'='Africa'; 'Southern South America'='South America'; 'Southwest and Basin'= 'North America'; 'Western Africa'='Africa'")

d.ct$subsistence2<-as.factor(d.ct$subsistence2)

##above, recoded d$region, according to SCCS region, using eHRAF subregion. BUT, one Southeast Asia (Central Thai) that should be East Eurasia coded as Insular Pacific
#### and 3 Western Africa coded as Africa that should be Circum Medeterainian (Dogon, Hause, Wolof)

###Recoding SCCS variables
d.ct$settlement_fixity2<-car::recode(d.ct$V61, "''='NA'; 'Impermanent-periodically moved'='Impermanent-periodically moved'; 'Migratory'='Migratory'; 'Permanent'='Permanent'; 'Rotating among 2+ fixed'='Impermanent-periodically moved'; 'Seminomadic-fixed then migratory'='Seminomadic'; 'Semisedentary-fixed core, some migratory'='Semisedentary'")

d.ct$com_size2<-car::recode(d.ct$V63, "''='NA'; '< 50'='< 99'; '1,000-4,999'='> 1,000'; '100-199'='100-199'; '200-399'='200-399'; '400-999'='400-999'; '50-99'='< 99'")

d.ct$pop_density2<-car::recode(d.ct$V64, "''='NA'; '< 1 person / 5 sq. mile'='≤ 1 person / 1-5 sq. mile'; '1 person / 1-5 sq. mile'='≤ 1 person / 1-5 sq. mile'; '1-25 persons / sq. mile'='1-25 persons / sq. mile'; '1-5 persons / sq. mile'='1-25 persons / sq. mile'; '101-500 persons / sq. mile'='101-500 persons / sq. mile'; '26-100 persons / sq. mile'='26-100 persons / sq. mile'; 'over 500 persons / sq. mile'='over 500 persons / sq. mile'")

d.ct$V69[d.ct$V69==""]=NA
d.ct$V69=factor(d.ct$V69)
#d.ct$V69<- recode(d.ct$V69, "'NA'='NA'; 'Ambilocal-w/ either wife\'s or husband\'s kin'='Ambilocal'; 'Avunculocal-w/husband\'s mother\'s brother\'s kin'='Avunculocal'; 'Matrilocal or uxorilocal-with wife\'s kin'='Matrilocal'; 'Neolocal-separate from kin'='Neolocal'; 'Patrilocal or virilocal'='Patrilocal'")

##### CREATING AGGREGATE DATA SET
## Summarize support for each variable by culture

# Score 1 if *any* extract within a culture has a 1 for that variable (*d.ct2 is culture level data [single count evidence for] for variable analyses)
# More accurately: balance of +1 against -1

d.ct2 = aggregate(d[,14:37], by=list(d$c_name), FUN = function(x) {(sum(x) > 0)*1})
d.ct2$c_name=d.ct2$Group.1
#creating a dataframe of means values of variables at culture level (*d.ct3 is culture level data [means of variables] for variables )
d.ct3 = aggregate(d[,14:37], by=list(d$c_name), FUN = mean)


##adding in some other culture level variables
#d.ct2 <-merge(d.ct, d.ct2, by="c_name")




## End

#### CREATING DATA FRAMES FOR MODELS ETC. (all extract level data frames for model totals)

## Creating variables based on models totaling for, none, and against
d$dom_for = rowSums(d[,c('dom_aggression', 'dom_fear', 'dom_assert.authority',
                           'dom_avoid.dom', 'dom_fighting', 'dom_personality',
                           'dom_reputation', 'dom_strong')]==1)

d$dom_against = rowSums(d[,c('dom_aggression', 'dom_fear', 'dom_assert.authority',
                               'dom_avoid.dom', 'dom_fighting', 'dom_personality',
                               'dom_reputation', 'dom_strong')]==-1)

d$dom_none = rowSums(d[,c('dom_aggression', 'dom_fear', 'dom_assert.authority',
                            'dom_avoid.dom', 'dom_fighting', 'dom_personality',
                            'dom_reputation', 'dom_strong')]==0)
d$dom_sum = d$dom_for + d$dom_against

d$prestige_for = rowSums(d[,c('prestige_counsel', 'prestige_emulated', 'prestige_expertise',
                                'prestige_family', 'prestige_f.exp.success', 'prestige_likable',
                                'prestige_respected')]==1)

d$prestige_against = rowSums(d[,c('prestige_counsel', 'prestige_emulated', 'prestige_expertise',
                                    'prestige_family', 'prestige_f.exp.success', 'prestige_likable',
                                    'prestige_respected')]==-1)

d$prestige_none = rowSums(d[,c('prestige_counsel', 'prestige_emulated', 'prestige_expertise',
                                 'prestige_family', 'prestige_f.exp.success', 'prestige_likable',
                                 'prestige_respected')]==0)
d$prestige_sum= d$prestige_for + d$prestige_against

d$neel_for = rowSums(d[,c('neel_better.mates', 'neel_big.family', 'neel_intelligence',
                            'neel_polygynous')]==1)

d$neel_against = rowSums(d[,c('neel_better.mates', 'neel_big.family', 'neel_intelligence',
                                'neel_polygynous')]==-1)

d$neel_none = rowSums(d[,c('neel_better.mates', 'neel_big.family', 'neel_intelligence',
                             'neel_polygynous')]==0)
d$neel_sum = d$neel_for + d$neel_against

d$hooper_for = rowSums(d[,c('hooper_performance','hooper_sanction.freeriders','hooper_payoff','hooper_group.size','hooper_coop.activities')]==1)

d$hooper_against = rowSums(d[,c('hooper_performance','hooper_sanction.freeriders','hooper_payoff','hooper_group.size','hooper_coop.activities')]==-1)

d$hooper_none = rowSums(d[,c('hooper_performance','hooper_sanction.freeriders','hooper_payoff','hooper_group.size','hooper_coop.activities')]==0)

d$hooper_sum = d$hooper_for + d$hooper_against

#### MERGING Culture level variables with extract level variables (*dm is extract level data, but with culture level variables attached to each extract)
dm <-merge(d, d.ct, by="c_name")


##new data frames by model (no culture name)
d.dom = d[,c(14:21)]
d.prest = d[,c(31:37)]
d.neel = d[,c(27:30)]
d.hooper = d[,c(22:26)]
#d.vv=d[,c(33:34)]
#d.vvstrat = d[,c(34)]
#d.vvcoord = d[,c(33)]
## these codes include culture names, removed from script
#d.dom = d[,c(5, 14:21)]
#d.prest = d[,c(5, 26:32)]
#d.neel = d[,c(5, 22:25)]
#d.vv=d[,c(5, 33:34)]
#d.vvstrat = d[,c(5, 34)]
#d.vvcoord = d[,c(5, 33)]

## making d.dom data set with only extracts that have data, e.g. removes all extracts with all noevidence
d.dom2 = d.dom[rowSums(d.dom!=0)!=0,]
## does not lose any cultures!!

## eliminating empty extracts from prestige model data set
d.prest2 = d.prest[rowSums(d.prest!=0)!=0,]
## does not loose any cultures

## for Neel model
d.neel2 = d.neel[rowSums(d.neel!=0)!=0,]
#does not lose any cultures

## for VV variables (both strat and coord in frame)
#d.vv2 = d.vv[rowSums(d.vv!=0)!=0,]
#does not lose any cultures

##making variables of totals for each model (these omit cases where there is a 1 and -1)
d$dom_totals = d$dom_aggression + d$dom_assert.authority + d$dom_avoid.dom + d$dom_fear + d$dom_fighting + d$dom_personality + d$dom_reputation + d$dom_strong
d$prest_totals = d$prestige_emulated + d$prestige_likable + d$prestige_counsel + d$prestige_expertise + d$prestige_f.exp.success + d$prestige_respected + d$prestige_family
d$neel_totals = d$neel_intelligence + d$neel_polygynous + d$neel_better.mates + d$neel_big.family
d$hooper_totals = d$hooper_performance + d$hooper_group.size + d$hooper_coop.activities + d$hooper_sanction.freeriders + d$hooper_payoff

## putting data in long form
d.tmp=melt(d[,c(1, 14:37)], id.vars='cs_ID')
head(d.tmp)
# table(d.tmp)
# table(d)
table(d.tmp$variable, d.tmp$value)
t=table(d.tmp$variable, d.tmp$value)
t

# Create new variables for variables with many -1 values

# Print tables of all variables to see which have many -1's
for (i in 11:29){
  print(names(d)[i])
  print(table(d[i]))
}

#Which bits of evidence against to keep?
t2 =t[t[,1]>0,]
t2[(t2[,1]/t2[,3])>=.10,]

leader_text_original <- d

#Cut off rule, keep all evidence against when it's greater than or equal to 10% of the codes for t

# dom_aggression has 14 -1's
d$dom_anti_aggression <- 0
d$dom_anti_aggression[d$dom_aggression == -1] <- 1
d$dom_aggression[d$dom_aggression == -1] <- 0

# dom_assert.authority has 83 -1's
d$dom_no_coercive_authority <- 0
d$dom_no_coercive_authority[d$dom_assert.authority == -1] <- 1
d$dom_assert.authority[d$dom_assert.authority == -1] <- 0

# dom_personality has 23 -1's
d$dom_non_dominant_personality <- 0
d$dom_non_dominant_personality[d$dom_personality == -1] <- 1
d$dom_personality[d$dom_personality == -1] <- 0

# hooper_sanction.freeriders has 3 -1s (to 16 1s)
d$hooper_no_sanctioning <- 0
d$hooper_no_sanctioning[d$hooper_sanction.freeriders == -1] <-1
d$hooper_sanction.freeriders[d$hooper_sanction.freeriders == -1] <- 0

# hooper_group.size has 3 -1s (to 16 1s)
d$hooper_leaderless_large_group <- 0
d$hooper_leaderless_large_group[d$hooper_group.size == -1] <-1
d$hooper_group.size[d$hooper_group.size == -1] <- 0

# hooper_group.size has 3 -1s (to 16 1s)
d$hooper_egalitarian_large_group <- 0
d$hooper_egalitarian_large_group[d$hooper_coop.activities == -1] <-1
d$hooper_coop.activities[d$hooper_coop.activities == -1] <- 0

# prestige_family has 12 -1's
d$prestige_no_family_prestige <- 0
d$prestige_no_family_prestige[d$prestige_family == -1] <- 1
d$prestige_family[d$prestige_family == -1] <- 0

# prestige_likable has 19 -1's
d$prestige_unlikeable <- 0
d$prestige_unlikeable[d$prestige_likable == -1] <- 1
d$prestige_likable[d$prestige_likable == -1] <- 0

# prestige_respected has 28 -1's
d$prestige_not_respected <- 0
d$prestige_not_respected[d$prestige_respected == -1] <- 1
d$prestige_respected[d$prestige_respected == -1] <- 0

#Removing codes of no evidence when cases of no evidence is less than 10%
d$dom_avoid.dom[d$dom_avoid.dom == -1] <- 0
d$dom_fear[d$dom_fear == -1] <- 0
d$dom_fighting[d$dom_fighting == -1] <- 0
d$dom_reputation[d$dom_reputation == -1] <- 0
d$hooper_performance[d$hooper_performance == -1] <- 0
d$hooper_sanction.freeriders[d$hooper_sanction.freeriders == -1] <- 0
d$hooper_payoff[d$hooper_payoff == -1] <- 0
d$hooper_group.size[d$hooper_group.size == -1] <- 0
d$hooper_coop.activities[d$hooper_coop.activities == -1] <- 0
d$neel_intelligence[d$neel_intelligence == -1] <- 0
d$prestige_counsel[d$prestige_counsel == -1] <- 0
d$prestige_emulated[d$prestige_emulated == -1] <- 0
d$prestige_expertise[d$prestige_expertise == -1] <- 0

#Fix emulated coding
d$prestige_emulated[d$cs_textrec_ID==1092] <- 1

#Remove cases of all 0s on theory variables
d<-d[rowSums(d[,c(14:37,73:81)])>0,]


## Compute mean and present variables at culture level
present = function(x) {(sum(x) > 0)*1}

d.ct <- d %>%
  dplyr::select(c_name, one_of(all_vars)) %>%
  group_by(c_name) %>%
  summarise_all(lst(present, mean)) %>%
  right_join(d.ct, by='c_name')

# Compute models scores by culture

## Left off here Oct 30, 2019
## Need to add model scores to d.ct, which has 1 extra row (59)
## Possible strategy: create data frame with the 58 rows
## for which we have data, and then merge with d.ct, which has all 59 rows

# Create a data frame of just the 58 cultures first
d_58<-d[!d$c_name=="Saramaka",]
d_58$c_name<-factor(d_58$c_name)

library(data.table)
d_58<-setorder(d_58, c_name)

# Calculate model scores
df_modelscores <-
  tibble(
    c_name = factor(unique(d_58$c_name)),
    neel_cult_score = as.numeric(by(d_58[,c('c_name', neel_vars)], d_58$c_name, FUN=function(x) mean(as.matrix(x[,-1]), na.rm=T))),
    prest_cult_score = as.numeric(by(d_58[,c('c_name', prest_vars)], d_58$c_name, FUN=function(x) mean(as.matrix(x[,-1]), na.rm=T))),
    dom_cult_score = as.numeric(by(d_58[,c('c_name', dom_vars)], d_58$c_name, FUN=function(x) mean(as.matrix(x[,-1]), na.rm=T))),
    hooper_cult_score = as.numeric(by(d_58[,c('c_name', hooper_vars)], d_58$c_name, FUN=function(x) mean(as.matrix(x[,-1]), na.rm=T)))
  )

# Merge model scores into d.ct

d.ct <- left_join(d.ct, df_modelscores, by = "c_name")

# d$c_name<-factor(d$c_name)
# d.ct$neel_cult_score = as.numeric(by(d[,c('c_name', neel_vars)], d$c_name, FUN=function(x) mean(as.matrix(x[,-1]), na.rm=T)))
# d.ct$prest_cult_score = as.numeric(by(d[,c('c_name', prest_vars)], d$c_name, FUN=function(x) mean(as.matrix(x[,-1]), na.rm=T)))
# d.ct$dom_cult_score = as.numeric(by(d[,c('c_name', dom_vars)], d$c_name, FUN=function(x) mean(as.matrix(x[,-1]), na.rm=T)))
# d.ct$hooper_cult_score = as.numeric(by(d[,c('c_name', hooper_vars)], d$c_name, FUN=function(x) mean(as.matrix(x[,-1]), na.rm=T)))


#Final renaming
d$subsistence<-d$subsistence2
d$region<-d$region2
d.ct$subsistence<-d.ct$subsistence2
d.ct$region<-d.ct$region2
d.ct$settlement_fixity<-d.ct$settlement_fixity2
d.ct$com_size<-d.ct$com_size2
d.ct$pop_density<-d.ct$pop_density2
d.ct$c_cultural_complexity[d.ct$c_name=='Hopi'] = 35
d.ct$c_cultural_complexity[d.ct$c_name=='Mataco'] = 18

doc_table<-read.csv('data-raw/culture_totals.csv')
doc_table<-doc_table[,c(1,14)]
d.ct<-left_join(d.ct,doc_table)

d_raw.text<-read_csv("data-raw/raw_text_updated.csv")
d_raw.text$raw_text<-d_raw.text$t_text
d_raw.text<-d_raw.text[,c("document_d_ID", "cs_textrec_ID", "t_split_record", "t_split_record_info", "raw_text")]

d_final<-left_join(d,d_raw.text, by="cs_textrec_ID")

# d.ctPKG<-d.ct[,c(1:53,132:167)]
levels(d.ct$subsistence) <-c("agriculturalists", "horticulturalists", "hunter gatherers", "mixed", "pastoralists")
levels(d.ct$subsistence2) <-c("agriculturalists", "horticulturalists", "hunter gatherers", "mixed", "pastoralists")


d.ctPKG <- dplyr::select(d.ct,
                         c_name,c_culture_code,
                         Location,
                         V158.1,
                         c_cultural_complexity:hooper_total_against,
                         neel_cult_score:documents
                         )

leader_cult <- cultures %>%
  dplyr::select(c_culture_code, Name, Region) %>%
  left_join(d.ctPKG, by = 'c_culture_code')

# Recode cultural char vars as ordinal

leader_cult$com_size <-
  ordered(
    leader_cult$com_size,
    levels = c("< 99", "100-199", "200-399", "400-999", "> 1,000")
  )

leader_cult$pop_density <-
  ordered(
    leader_cult$pop_density,
    levels = c(
      "1 or less person / 1-5 sq. mile",
      "1-5 persons / sq. mile",
      "1-25 persons / sq. mile",
      "26-100 persons / sq. mile",
      "101-500 persons / sq. mile",
      "over 500 persons / sq. mile"
    )
  )

# Create leader_text

leader_text<-dplyr::select(d_final,
                           cs_ID:evidence_hooper_against,
                           dom_for:raw_text)

# Rename text record data frame -------------------------------------------

text_records <- d_raw.text

# Words data frame for text analysis -------------------------------

leader_words <-
  text_records %>%
  dplyr::select(cs_textrec_ID, raw_text) %>%
  mutate(
    raw_text = iconv(raw_text, "", "UTF-8"),
    raw_text = str_replace(raw_text, "’", "'") # Switch ’ to '
  ) %>%
  unnest_tokens(word, raw_text) %>%
  mutate(
    word = str_to_lower(word),
    word = str_replace(word, "'s", "")
    ) %>%
  dplyr::filter(!str_detect(word, "\\d+")) %>%
  dplyr::filter(!str_detect(word, 'page')) %>%
  anti_join(stop_words) %>%
  dplyr::filter(str_count(word) > 2 | word == 'ox') %>%
  mutate(lemma = lemmatize_words(word))

# document-term matrix
leader_dtm <-
  leader_words %>%
  dplyr::select(cs_textrec_ID, lemma) %>%
  group_by(cs_textrec_ID, lemma) %>%
  summarise(count = n()) %>%
  spread(lemma, count, fill = 0) %>%
  ungroup

# Two letter words that were removed (and their frequency). Kept "ox"
#
# ac ax er fo fr fu ga ha hò ix la lb mm mo na ne nw oi ot pe ph pt qa ra sa sp
# 1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1
# ta tb ti ué uj ur wi xv ba ea es gu im ko ma ms mu nä ol pa se sh uu xi du ed
# 1  1  1  1  1  1  1  1  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  2  3  3
# iv ki ku oa pl si st vi ya ad bu ge li po en op ri wa al ch dr el ho uh ii
# 3  3  3  3  3  3  3  3  3  4  4  4  4  4  5  5  5  5  6  6  7  7  9  9  13
# ka de pp cf
# 13 14 20 22

# Import documents data frame ---------------------------------------------

documents <-
  read_excel("data-raw/documents.xlsx") %>%
  rename(
    d_publication_date = `d_publication date`
  ) %>%
  mutate(
    d_field_date_start = as.numeric(d_field_date_start),
    d_field_date_end = as.numeric(d_field_date_end),
    d_publication_date = as.numeric(d_publication_date),
    # One missing pub date. Replace with d_field_date_end + 5 yrs
    d_publication_date = case_when(
      is.na(d_publication_date) ~ d_field_date_end + 5,
      TRUE ~ d_publication_date
    )
  ) %>%
  dplyr::select(d_ID, d_title, d_publication_date, everything())


# Text record coding related to leadership costs, benefits, qualit --------
# qualities, functions, and group structure

leader_text2 <- read_csv("data-raw/reconciled_coding2.csv")

# Reset code sheet IDs for d2 (leader_text2) to avoid any confusion with leader_text coding.
leader_text2$cs_ID<-seq.int(20001,21212)

# Recode -1's

# First, figure out which vars have -1's, and how many
negs <-
  leader_text2[-c(1:3)] %>%
  select_if(is.numeric) %>%
  map_dbl(~sum(.x < 0))

# An how many +1's
pos <-
  leader_text2[-c(1:3)] %>%
  select_if(is.numeric) %>%
  map_dbl(~sum(.x > 0))

# if ratio of negs to pos is > 0.1 create new anti vars
ratio <- negs/pos
ratio[ratio>0.1]

leader_text2$qualities_AntiHonest <-
  ifelse(leader_text2$qualities_Honest == -1, 1, 0)

leader_text2$qualities_AntiFairness <-
  ifelse(leader_text2$qualities_Fairness == -1, 1, 0)

leader_text2$qualities_AntiDrugConsumption <-
  ifelse(leader_text2$qualities_DrugConsumption == -1, 1, 0)

leader_text2$qualities_AntiCoerciveAuthority <-
  ifelse(leader_text2$qualities_CoerciveAuthority == -1, 1, 0)

leader_text2_original <- leader_text2

leader_text2 <-
  map_if(leader_text2_original, is.numeric, ~ ifelse(.x < 0, 0, .x)) %>%
  as_tibble

# Compare to negs, pos
negs2 <-
  leader_text2[-c(1:3)] %>%
  select_if(is.numeric) %>%
  map_dbl(~sum(.x < 0))

pos2 <-
  leader_text2[-c(1:3)] %>%
  select_if(is.numeric) %>%
  map_dbl(~sum(.x > 0))

# Import author and authorship data ---------------------------------------

authorship <- read_excel("data-raw/authorship.xlsx")


# Recode variables --------------------------------------------------------

# Add sex
leader_text_original$demo_sex <- as.character(leader_text_original$demo_sex)
leader_text_original$demo_sex[leader_text_original$demo_sex == "-1"] <- "male"
leader_text_original$demo_sex[leader_text_original$demo_sex == "unkown"] <- "unknown"
leader_text2 <- left_join(leader_text2, leader_text_original[c("cs_textrec_ID", "demo_sex")])

# Aggregate group structure types

group_str <- c(
  "state-level group" = "political group (supracommunity)",
  "religeous group" = "religious group", # correct spelling
  "political group (community)" = "political group (community)",
  "political group (supracommunity)" = "political group (supracommunity)",
  "military group" = "military group",
  "economic group" = "economic group",
  "criminal group" = "economic group",
  "labor group" = "economic group",
  "subsistence group" = "economic group",
  "age-group" = "residential subgroup",
  "domestic group" = "kin group",
  "kin group" = "kin group",
  "local group" = "residential subgroup",
  "performance group" = "residential subgroup",
  "other" = "other",
  "multiple domains" = "other",
  "unkown" = "other"
)

leader_text2$group.structure2 <- leader_text2$group.structure_Coded
leader_text2$group.structure2 <- group_str[leader_text2$group.structure2]

# Female coauthor ---------------------------------------------------------

female_coauthor <- function(document_ID){
  author_genders <- authorship$author_gender[authorship$document_ID == document_ID]
  'female' %in% author_genders
}

documents$female_coauthor <- map_lgl(documents$d_ID, female_coauthor)

# Merge more culture-level data -------------------------------------------

# number of text records for each culture
tbl_ntr <- table(leader_text_original$c_culture_code)

dfntr <- tibble(
  "OWC Code" = names(tbl_ntr),
  number_leader_records = as.numeric(tbl_ntr)
)

# get number of pages for PSF cultures only
dfwc <-
  read_excel("data-raw/WC_SummaryPublishedCollections_20180625.xlsx") %>%
  dplyr::filter(`PSF eHRAF` == 'Yes') %>%
  left_join(dfntr) %>%
  dplyr::select(`OWC Code`, `N Pages eHRAF`, number_leader_records)

leader_cult <-
  leader_cult %>%
  left_join(dfwc, by = c('c_culture_code' = 'OWC Code')) %>%
  rename(
    ehraf_pages = `N Pages eHRAF`
  )

# Convert factors to chars ------------------------------------------------

documents <- mutate_if(documents, is.factor, as.character)
authorship <- mutate_if(authorship, is.factor, as.character)
leader_text <- mutate_if(leader_text, is.factor, as.character)
leader_cult <- mutate_if(leader_cult, is.factor, as.character)
leader_text_original <- mutate_if(leader_text_original, is.factor, as.character)
text_records <- mutate_if(text_records, is.factor, as.character)
leader_text2 <- mutate_if(leader_text2, is.factor, as.character)


# Nice var names ----------------------------------------------------------

var_names <- c(
  "functions_BestowMate" = "Bestow mates",
  "functions_PoliticalAppointments" = "Political appointments",
  "functions_ConstructionInfrastructure"       = "Construction/infastructure",
  "functions_ControlEconomics"                 = "Control economics",
  "functions_CouncilMember"                    = "Council member",
  "functions_GroupDetermination"              = "Group determination/cohesiveness",
  "functions_Hospitality"                       = "Hospitality",
  "functions_MilitaryCommand"                  = "Military command",
  "functions_NewSettlement"                    =  "Movement/migration",
  "functions_ProsocialInvestment"              = "Prosocial investment",
  "functions_ProvideCounsel"                   = "Provide counsel/direction",
  "functions_Punishment"                        = "Punishment",
  "functions_ServeLeader"                      = "Serve a leader",
  "functions_StrategicPlanning" = "Strategic planning",
  "functions_OrganizeCooperation"  = "Organize cooperation",
  "functions_ResolveConflcit"      = "Resolve conflict",
  "functions_ControlCalendar"     = "Control calendar",
  "functions_ControlImmigration"  = "Control immigration",
  "functions_DistributeResources" = "Distribute resources",
  "functions_GroupRepresentative" = "Group representative",
  "functions_Medicinal"           = "Medicinal functions",
  "functions_MoralAuthority"     = "Moral authority",
  "functions_Policymaking"        =  "Policy making",
  "functions_Protection"          = "Protection",
  "functions_ProvideSubsistence" = "Provide subsistence",
  "functions_Ritual"              = "Ritual functions",
  "functions_SocialFunctions" = "Misc. social functions",
  "qualities_ArtisticPerformance"     = "Artistic performance",
  "qualities_Generous"                 = "Generosity",
  "qualities_Age"                      = "Age",
  "qualities_Attractive"              = "Attractive",
  "qualities_CoerciveAuthority"      = "Coercive authority",
  "qualities_CulturallyProgressive"  = "Culturally progressive",
  "qualities_FavorablePersonality"   = "Favorable personality",
  "qualities_Honest"                  = "Honesty",
  "qualities_IngroupMember"          = "Ingroup member",
  "qualities_Killer"                  = "Killer",
  "qualities_ManyChildren"           = "Many children",
  "qualities_PhysicallyStrong"       = "Physically formidable",
  "qualities_Prosocial"               = "Prosocial",
  "qualities_StrategicPlanner"       = "Strategic planner",
  "qualities_DrugConsumption"     = "Drug consumption",
  "qualities_HighStatus"            = "High status",
  "qualities_Aggressive"             = "Aggressiveness",
  "qualities_Bravery"               = "Bravery",
  "qualities_Confident"             = "Confidence",
  "qualities_Decisive"              = "Decisiveness/decision-making",
  "qualities_Feared"                = "Feared",
  "qualities_Humble"                = "Humility",
  "qualities_Innovative"            = "Innovative",
  "qualities_KnowlageableIntellect" = "Knowledgeable/intelligent",
  "qualities_OratorySkill"         = "Oratory skill",
  "qualities_Polygynous"            = "Polygynous",
  "qualities_SocialContacts"       = "Social contacts",
  "qualities_Supernatural"    = "Supernatural",
  "qualities_ExpAccomplished"       = "Experienced/accomplished",
  "qualities_Wealthy"                = "Wealthy",
  "qualities_Ambition"               = "Ambitious",
  "qualities_Charisma"               = "Charisma",
  "qualities_CulturallyConservative" = "Culturally conservative",
  "qualities_Fairness"               = "Fairness",
  "qualities_HighQualitySpouse"    = "High-quality spouse",
  "qualities_Industriousness"        = "Industriousness",
  "qualities_InterpersonalSkills"   = "Interpersonal skills",
  "qualities_Loyalty"                = "Loyalty",
  "qualities_PhysicalHealth"        = "Physical health",
  "qualities_ProperBehavior"        = "Proper behavior",
  "qualities_StrategicNepotism"     = "Strategic nepotism",
  "qualities_Xenophobic"   = "Xenophobia",
  "qualities_AntiHonest" = "Dishonest",
  "qualities_AntiFairness" = "Unfair",
  "qualities_AntiDrugConsumption" = "No drug consumption",
  "qualities_AntiCoerciveAuthority" = "No coercive authority",
  leader.benefits_Fitness = 'Inclusive fitness benefit',
  leader.benefits_Mating = 'Mating benefit',
  leader.benefits_Other = 'Misc. non-material benefit',
  leader.benefits_RiskHarmConflict = 'Reduced risk of harm',
  leader.benefits_ResourceFood = 'Food benefit',
  leader.benefits_ResourceOther = 'Material resources',
  leader.benefits_SocialServices = 'Social services',
  leader.benefits_SocialStatusReputation = 'Increased social status',
  leader.benefits_Territory = 'Territory',
  follower.benefits_Fitness = 'Inclusive fitness benefit',
  follower.benefits_Mating = 'Mating benefit',
  follower.benefits_Other = 'Misc. non-material benefit',
  follower.benefits_RiskHarmConflict = 'Reduced risk of harm',
  follower.benefits_ResourceFood = 'Food benefit',
  follower.benefits_ResourceOther = 'Material resources',
  follower.benefits_SocialServices = 'Social services',
  follower.benefits_SocialStatusReputation = 'Increased social status',
  follower.benefits_Territory = 'Territory',

  leader.costs_Fitness = 'Inclusive fitness cost',
  leader.costs_RiskHarmConflict = 'Increased risk of harm',
  leader.costs_Other = 'Misc. non-material cost',
  leader.costs_ResourceFood = 'Food cost',
  leader.costs_ResourceOther = 'Loss of material resources',
  leader.costs_SocialStatusReputation = 'Reduced social status',
  leader.costs_Territory = 'Loss of territory',
  leader.costs_Mating = 'Mating cost',
  leader.costs_SocialServices = 'Loss of social services',
  follower.costs_Fitness = 'Inclusive fitness cost',
  follower.costs_RiskHarmConflict = 'Increased risk of harm',
  follower.costs_Mating = 'Mating cost',
  follower.costs_Other = 'Misc. non-material cost',
  follower.costs_ResourceFood = 'Food cost',
  follower.costs_ResourceOther = 'Loss of material resources',
  follower.costs_SocialServices = 'Loss of social services',
  follower.costs_SocialStatusReputation = 'Reduced social status',
  follower.costs_Territory = 'Loss of territory'
)

# Write data --------------------------------------------------------------

use_data(documents, authorship, leader_text, leader_text2_original, leader_text2, leader_cult, leader_text_original, text_records, leader_words, leader_dtm, var_names, overwrite=TRUE)

