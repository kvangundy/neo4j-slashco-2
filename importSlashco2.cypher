//one graph, four ways: visualization, NLP, a social network, real-time and cached recommendations, and a little bit of fraud detection
//
//contraints & indexes
CREATE CONSTRAINT ON (p:User) ASSERT p.userID IS UNIQUE;
CREATE CONSTRAINT ON (p:User) ASSERT p.email IS UNIQUE;
CREATE CONSTRAINT ON (p:User) ASSERT p.facebookID IS UNIQUE;
CREATE CONSTRAINT ON (p:User) ASSERT p.twitterID IS UNIQUE;
CREATE CONSTRAINT ON (i:Item) ASSERT i.itemID IS UNIQUE;
CREATE CONSTRAINT ON (r:Region) ASSERT r.name IS UNIQUE;
CREATE CONSTRAINT ON (r:SubRegion) ASSERT r.name IS UNIQUE;
CREATE CONSTRAINT ON (t:Transaction) ASSERT t.transactionID IS UNIQUE;
CREATE CONSTRAINT ON (i:IP_ADDRESS) ASSERT i.ipAddress IS UNIQUE;
CREATE CONSTRAINT ON (t:Tag) ASSERT t.name IS UNIQUE;
CREATE INDEX ON :City(name);
CREATE INDEX ON :Period(period);
CREATE INDEX ON :Transaction(outcome);
//
//create time tree
WITH range(1,52) as periods
FOREACH (period IN periods |
  MERGE (p:Period {period:period}));
//
MATCH (p:Period)
WITH p
ORDER BY p.period
WITH COLLECT(p) as periods
FOREACH (i in RANGE(0,length(periods)-2) |
  FOREACH(p1 in [periods[i]] |
      FOREACH(p2 in [periods[i+1]] |
          CREATE UNIQUE (p1)-[:NEXT]->(p2))));
//
LOAD CSV WITH HEADERS FROM "file:///Users/kevinvangundy/Desktop/Neo4j-Projects/aGraph3Ways/usersDump.csv" as line
WITH line
CREATE (:User {name:line.name, userID:line.userUUID, email:line.email, facebookID:line.facebookID, twitterID:line.twitterID});
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/userDump.csv" as line
WITH line, split(line.twitterFollowers, ",") as twitters
MATCH (root:User {userID:line.userUUID})
WITH twitters, root
UNWIND twitters AS userID
MERGE (other:User {userID:userID})
MERGE (root)-[:TWITTER_FOLLOW]->(other);
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/userDump.csv" as line
WITH line, split(line.facebookFriends, ",") as facebooks
MATCH (root:User {userID:line.userUUID})
WITH facebooks, root
UNWIND facebooks AS userID
MERGE (other:User {userID:userID})
MERGE (root)-[:FACEBOOK]-(other);
//
//cleanup self and double followers from my shitty data
MATCH (narcissist:User)-[selfLove:TWITTER_FOLLOW]->(narcissist)
DELETE selfLove;
MATCH (narcissist:User)-[redundant:TWITTER_FOLLOW]->(narcissist2)<-[okay:TWITTER_FOLLOW]-(narcissist)
DELETE redundant;
MATCH (narcissist:User)-[selfLove:FACEBOOK]->(narcissist)
DELETE selfLove;
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/userDump.csv" as line
WITH line
MERGE (r:Region {name:line.region})
MERGE (rr:SubRegion {name:line.subRegion})
MERGE (rrr:City {name:line.city})
MERGE (r)-[:HAS_SUBREGION]->(rr)
MERGE (rr)-[:HAS_CITY]->(rrr)
WITH rrr, line
MATCH (u:User {userID:line.userUUID})
MERGE (u)-[:LIVES_IN]->(rrr);
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/inventoryDump.csv" as line
WITH line, toINT(line.price) as price, toINT(line.itemUUID) as itemID
CREATE (:Item {itemID:itemID, name:line.name, price:price});
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/inventoryDump.csv" as line
WITH line
MERGE (:Category {name:line.globalCategory})
MERGE (:Category {name:line.subCategory})
MERGE (:Category {name:line.minorCategory});
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/inventoryDump.csv" as line
WITH line
MATCH  (g:Category {name:line.globalCategory}),(s:Category {name:line.subCategory})
MERGE (g)-[:HAS_SUBCATEGORY]->(s);
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/inventoryDump.csv" as line
WITH line
MATCH  (m:Category {name:line.minorCategory}),(s:Category {name:line.subCategory})
MERGE (s)-[:HAS_MINORCATEGORY]->(m);
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/inventoryDump.csv" as line
WITH line
MATCH  (m:Category {name:line.minorCategory}), (item:Item {itemID:toINT(line.itemUUID)})
MERGE (item)-[:IN_CATEGORY]->(m);
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/inventoryDump.csv" as line
WITH split(line.tags, ",") as tags
UNWIND tags as tag
MERGE (:Tag {name:tag});
//
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/inventoryDump.csv" as line
WITH line, split(line.tags, ",") as tags
UNWIND tags as tag
MATCH (i:Item {itemID:toINT(line.itemUUID)}), (t:Tag {name:tag})
MERGE (i)-[:TAGGED]->(t);
//
//cleanup FALSE
MATCH (n:Tag {name:"FALSE"})
OPTIONAL MATCH (n)-[r]-()
DELETE n,r;
//
//carts!
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/transactionDump.csv" as line
WITH line, toINT(line.transactionID) as tID
CREATE (:Transaction {transactionID:tID,outcome:line.outcome});
//
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/transactionDump.csv" as line
WITH line, toINT(line.transactionID) as tID, split(line.itemsCart, ",") as items
UNWIND items as item
MATCH (t:Transaction {transactionID:tID}), (i:Item {itemID:toINT(item)})
MERGE (t)-[r:IN_CART]->(i)
ON CREATE SET r.quantity = 1
ON MATCH SET r.quantity =  r.quantity + 1;
//
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/transactionDump.csv" as line
WITH line
MERGE (:IP_ADDRESS {ipAddress:line.buyerIP});
//
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/transactionDump.csv" as line
WITH line, toINT(line.transactionID) as tid
MATCH (ip:IP_ADDRESS {ipAddress:line.buyerIP}), (tx:Transaction {transactionID:tid})
CREATE (ip)<-[:IP_ADDRESS]-(tx);
//
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/transactionDump.csv" as line
WITH line, toINT(line.transactionID) as tid, toINT(line.period) as pd
MATCH (period:Period {period:pd}), (tx:Transaction {transactionID:tid})
CREATE (period)<-[:PERIOD]-(tx);
//
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/coreDataSets/transactionDump.csv" as line
WITH line, toINT(line.transactionID) as tid
MATCH (user:User {userID:line.buyerUUID}), (tx:Transaction {transactionID:tid})
CREATE (tx)<-[:CREATED_CART]-(user);
//
//reviews
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-slashco-2/master/samplereviews/reviews.csv" as line
WITH line, toINT(line.itemID) as itemID, toINT(line.unixDate) as time
CREATE (r:Review {review:line.review, timestamp:time, analyzed:FALSE})
WITH itemID, line.userID as userID, r
MATCH (u:User {userID:userID}), (i:Item {itemID:itemID})
CREATE (u)-[:WROTE_REVIEW]->(r), (i)<-[:ITEM_REVIEW]-(r);
//
//Sentiment Dictionary Import
CREATE CONSTRAINT ON (w:Word) ASSERT w.word IS UNIQUE;
CREATE CONSTRAINT ON (p:Polarity) ASSERT p.polarity IS UNIQUE;
CREATE
(:Polarity {polarity:"positive"}),
(:Polarity {polarity:"negative"});
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-sentiment-analysis/master/sentimentDict.csv" AS line
WITH line
MERGE (a:Word {word:line.word})
ON CREATE SET a.partSpeech = line.wordType, a.wordType = line.stype;
USING PERIODIC COMMIT
LOAD CSV WITH HEADERS FROM "https://raw.githubusercontent.com/kvangundy/neo4j-sentiment-analysis/master/sentimentDict.csv" AS line
WITH line
WHERE NOT line.polarity = 'neutral'
MATCH (w:Word {word:line.word}), (p:Polarity {polarity:line.polarity})
MERGE (w)-[:SENTIMENT]->(p);
