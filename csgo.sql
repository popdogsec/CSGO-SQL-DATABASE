/*
Benjamin Schafer 1
 
This is a database designed to store results from a Counter-Strike Global Offensive Tournament. For demo purposes, data was inserted starting from the quarter-finals of the ELEAGUE Boston 2018 Major Tournament. Data was harvested from https://www.hltv.org/results?event=3247. This database sets up four tables (Player, Team, Match, Player_Statistics), a user function to calculate a players total kills or deaths, a stored procedure to determine how many games it took to determine a match, a procedure to figure the MVP of a Game, a trigger to calculate KD ratios on the fly during data insertion and a Overall_Performance view that can be Order to show who did the best and worst by Kills, Deaths and KD Ratio.
 
*/
 
 
--Define Tables and Alter Tables to Build Proper Tables for Use
 
CREATE TABLE Player(
in_game_name varchar(20) PRIMARY KEY,
f_name varchar(20) NOT NULL,
l_name varchar(20) NOT NULL);
 
CREATE TABLE Team(
team_name varchar(20) PRIMARY KEY,
p1_ign varchar (20) REFERENCES Player(in_game_name),
p2_ign varchar (20) REFERENCES Player(in_game_name),
p3_ign varchar (20) REFERENCES Player(in_game_name),
p4_ign varchar (20) REFERENCES Player(in_game_name),
p5_ign varchar (20) REFERENCES Player(in_game_name));
 
ALTER TABLE Player
ADD team_name varchar(20),
FOREIGN KEY (team_name)
REFERENCES Team(team_name);
 
CREATE TABLE Matches(
Match_ID int PRIMARY KEY,
Map_Name varchar(15) NOT NULL,
team_1 varchar (20),
team_1_first_half int,
team_1_second_half int,
team_1_score int,
team_2 varchar (20),
team_2_first_half int,
team_2_second_half int,
team_2_score int,
best_of_three int,
FOREIGN KEY (team_1)
REFERENCES Team(team_name),
FOREIGN KEY (team_2)
REFERENCES Team(team_name));
 
CREATE TABLE Player_Statistics(
match int REFERENCES Matches(Match_ID) NOT NULL,
in_game_name varchar(20) REFERENCES Player(in_game_name) NOT NULL,
team_name varchar (20) REFERENCES Team(team_name) NOT NULL,
Kills int,
Deaths int,
Assists int,
ADR decimal(4,1),
HS_Percentage int,
KD decimal (3,2),
PRIMARY KEY (match, in_game_name));
 
GO
 
--Trigger to calculate KD on the fly and display a proper amount of trailing decimals
 
CREATE TRIGGER KD_Calculation
ON Player_Statistics
INSTEAD OF INSERT
AS
BEGIN
INSERT INTO Player_Statistics
    SELECT match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage, (CAST(Kills AS float)/Deaths)
    FROM inserted
END
 
GO
 
--Processes to determine how many games were needed to determine a Match
--To utilize run EXEC best_of_three 'team1name', 'team2name' where Team 1 and Team 2 names are the two teams that participated in a given match
 
CREATE PROC best_of_three
@team1 varchar(20), @team2 varchar(20)
 
AS
DECLARE @bo3 int
 
SET @bo3 = (SELECT MAX(best_of_three)
            FROM Matches
            WHERE (team_1 = @team1 AND team_2 = @team2) OR (team_2 = @team1 AND team_1 = @team2))
 
IF @bo3 = 3 PRINT 'This Match took 3 Games to decide.'
ELSE IF @bo3 = 2 PRINT 'This Match took only 2 Games to decide.'
ELSE IF @bo3 = 0 PRINT 'This Match was not determined via Best of Three.'
ELSE PRINT 'Match information is not available. Either the teams not having played each other, or the match is still in progress.';
 
GO
 
--Stored Procedure to Figure out the MVP of a Specified Game.
--To utilize run EXEC MVP 'matchID' where matchID is the match ID from the Matches Table of the Game in question
CREATE PROC MVP
@match int
 
AS
DECLARE @kills int, @assists int
SELECT @kills = MAX(Kills)
FROM Player_Statistics
WHERE Match=@match;
SELECT @assists = MAX(Assists)
FROM Player_Statistics
WHERE Match=@match AND Kills=@kills;
SELECT in_game_name AS MVP, Kills, Deaths, Assists
FROM Player_Statistics
WHERE Match=@match AND Kills=@kills AND Assists=@assists;
 
GO
 
--Stored Procedure to clear records of a banned cheater
--To utilize first update the team of the cheater with its new roster, then run EXEC ban 'in_game_name', where in_game_name is the user name of the cheater
 
CREATE PROCEDURE ban
@in_game_name varchar(20)
AS
 
UPDATE Player
SET team_name = null
where in_game_name = @in_game_name;
 
ALTER TABLE Player_Statistics
NOCHECK CONSTRAINT FK__Player_St__in_ga__1ED998B2;
 
ALTER TABLE Player_Statistics
NOCHECK CONSTRAINT FK__Player_St__match__1DE57479;
 
ALTER TABLE Player_Statistics
NOCHECK CONSTRAINT FK__Player_St__team___1FCDBCEB;
 
 DELETE Player
 WHERE in_game_name = @in_game_name;
 DELETE Player_Statistics
 WHERE in_game_name = @in_game_name;
 
ALTER TABLE Player_Statistics
WITH CHECK CHECK CONSTRAINT FK__Player_St__in_ga__1ED998B2;
 
ALTER TABLE Player_Statistics
WITH CHECK CHECK CONSTRAINT FK__Player_St__match__1DE57479;
 
ALTER TABLE Player_Statistics
WITH CHECK CHECK CONSTRAINT FK__Player_St__team___1FCDBCEB;
 
GO
 
--Function to return the total kills or deaths of a give player
--To utilize run SELECT dbo.total('IGN', 'X'), where IGN is the In Game Name of the target player and  X is K for kills or D for Death
CREATE FUNCTION total(@in_game_name varchar(20), @flag varchar(1))
    RETURNS INT
    AS
            BEGIN
             DECLARE @returnvalue int
                 
                     IF (@flag = 'd')   SET @returnvalue = (SELECT SUM(Deaths) FROM Player_Statistics WHERE in_game_name = @in_game_name)
                     ELSE IF (@flag = 'k') SET @returnvalue = (SELECT SUM(Kills) FROM Player_Statistics WHERE in_game_name = @in_game_name)
                     ELSE SET @returnvalue = NULL
 
                RETURN @returnvalue
            END;
 
GO
 
/*View of Overall Performance
 
To sort by kills:
SELECT *
FROM Overall_performance
ORDER BY Total_Kills DESC;
 
To sort by deaths:
SELECT *
FROM Overall_performance
ORDER BY Total_Deaths DESC;
 
To sort by KD Ratio:
SELECT *
FROM Overall_performance
ORDER BY KD DESC;
 
Note that DESC can be eliminated to sort in ascending order.
*/
 
CREATE VIEW Overall_Performance
AS
SELECT in_game_name, SUM(Kills) AS 'Total Kills', SUM (DEATHS) AS 'Total Deaths', CAST((SUM(Kills)*1.0)/SUM(Deaths) AS DECIMAL(3,2)) AS 'TOTAL KD'
FROM Player_Statistics
GROUP BY in_game_name
 
GO

/*View of all players that played in each game
 
To Utilize:
Select *
From Roster;
 
*/

CREATE VIEW Roster
AS
SELECT Matches. Match_ID, Matches.team_1 AS 'Team 1', T1.p1_ign AS 'Team 1 Player 1', T1.p2_ign AS 'Team 1 Player 2', T1.p3_ign AS 'Team 1 Player 3', T1.p4_ign AS 'Team 1 Player 4', T1.p5_ign AS 'Team 1 Player 5', 
	Matches.team_2 AS 'Team 2', T2.p1_ign AS 'Team 2 Player 1', T2.p2_ign AS 'Team 2 Player 2', T2.p3_ign AS 'Team 2 Player 3', T2.p4_ign AS 'Team 2 Player 4', T2.p5_ign AS 'Team 2 Player 5'

FROM Matches
INNER JOIN Team T1 on (Matches.team_1 = T1.team_name)
INNER JOIN Team T2 on (Matches.team_2 = T2.team_name);

GO

 
/*View of all Overtime Matches
 
To Utilize:
Select *
From Overtime;
 
*/
 
CREATE VIEW Overtime
AS
SELECT Match_ID, team_1 AS 'Team 1', team_1_score AS 'Team 1 Score', team_2 AS 'Team 2', team_2_score AS 'Team 2 Score', ((team_1_score - 15) + (team_2_score -15)) AS 'Number of Overtime Rounds'
FROM Matches
WHERE team_1_score > 15 AND team_2_score > 15;
 
GO
--Begin Inserting Data
 
INSERT INTO Team (team_name) VALUES ('FAZE');
INSERT INTO Team (team_name) VALUES ('MOUSESPORTS');
INSERT INTO Team (team_name) VALUES ('NATUS VINCERE');
INSERT INTO Team (team_name) VALUES ('QB FIRE');
INSERT INTO Team (team_name) VALUES ('G2 ESPORTS');
INSERT INTO Team (team_name) VALUES ('CLOUD9');
INSERT INTO Team (team_name) VALUES ('SK GAMING');
INSERT INTO Team (team_name) VALUES ('FNATIC');
 
INSERT INTO Player VALUES ('GuardiaN','Ladislav','Kovacs','FAZE');
INSERT INTO Player VALUES ('karrigan','Finn','Anderson','FAZE');
INSERT INTO Player VALUES ('Niko','Nikola','Kovac','FAZE');
INSERT INTO Player VALUES ('olofmeister','olof','Kajbjer','FAZE');
INSERT INTO Player VALUES ('Rain','Harvard','Nygaard','FAZE');
 
INSERT INTO Player VALUES ('chrisJ','Chris','de Jong','MOUSESPORTS');
INSERT INTO Player VALUES ('oskar','Tomas','Stastny','MOUSESPORTS');
INSERT INTO Player VALUES ('ropz','Robin','Kool','MOUSESPORTS');
INSERT INTO Player VALUES ('STYKO','Martin','Styk','MOUSESPORTS');
INSERT INTO Player VALUES ('suNny','Miikka','Kemppi','MOUSESPORTS');
 
INSERT INTO Player VALUES ('Edward','Ioann','Sukhariev','NATUS VINCERE');
INSERT INTO Player VALUES ('electronic','Denis','Sharipov','NATUS VINCERE');
INSERT INTO Player VALUES ('flamie','Egor','Vasiliev','NATUS VINCERE');
INSERT INTO Player VALUES ('s1mple','Alexander','Kostyliev','NATUS VINCERE');
INSERT INTO Player VALUES ('Zeus','Daniil','Teslenko','NATUS VINCERE');
 
INSERT INTO Player VALUES ('balblna','Gregori','Oleinik','QB FIRE');
INSERT INTO Player VALUES ('Boombl4','Kirill','Mikhailov','QB FIRE');
INSERT INTO Player VALUES ('jmqa','Savelii','Bragin','QB FIRE');
INSERT INTO Player VALUES ('Kvik','Aurimas','Kvaksys','QB FIRE');
INSERT INTO Player VALUES ('waterfaLLZ','Nikita','Mateev','QB FIRE');
 
INSERT INTO Player VALUES ('apEX','Dan','Madesclaire','G2 ESPORTS');
INSERT INTO Player VALUES ('bodyy','Alexandre','Pianaro','G2 ESPORTS');
INSERT INTO Player VALUES ('KennyS','Kenny','Schmitt','G2 ESPORTS');
INSERT INTO Player VALUES ('NBK','Nathan','Schmitt','G2 ESPORTS');
INSERT INTO Player VALUES ('shox','Richard','Papillon','G2 ESPORTS');
 
INSERT INTO Player VALUES ('autimatic','Timothy','Ta','CLOUD9');
INSERT INTO Player VALUES ('RUSH','Will','Wierzba','CLOUD9');
INSERT INTO Player VALUES ('Skadoodle','Tyler','Latham','CLOUD9');
INSERT INTO Player VALUES ('Stewie2K','Jacky','Yip','CLOUD9');
INSERT INTO Player VALUES ('tarik','Tarik','Celik','CLOUD9');
 
INSERT INTO Player VALUES ('coldzera','Marcelo','David','SK GAMING');
INSERT INTO Player VALUES ('Fallen','Gabriel','Toledo','SK GAMING');
INSERT INTO Player VALUES ('felps','Joao','Vasconcellos','SK GAMING');
INSERT INTO Player VALUES ('fer','Fernando','Costa','SK GAMING');
INSERT INTO Player VALUES ('TACO','Epitacio',' de Melo','SK GAMING');
 
INSERT INTO Player VALUES ('flusha','Carl','Ronnquist','FNATIC');
INSERT INTO Player VALUES ('Golden','Maikil','Salim','FNATIC');
INSERT INTO Player VALUES ('JW','Bengt','Wecksell','FNATIC');
INSERT INTO Player VALUES ('KRIMZ','Lars','Johansson','FNATIC');
INSERT INTO Player VALUES ('Lekr0','Jonas','Olofsson','FNATIC');
 
UPDATE Team
SET p1_ign ='GuardiaN', p2_ign ='karrigan', p3_ign ='Niko', p4_ign ='olofmeister', p5_ign ='Rain'
WHERE team_name = 'FAZE';
 
UPDATE Team
SET p1_ign ='chrisJ', p2_ign ='oskar', p3_ign ='ropz', p4_ign ='STYKO', p5_ign ='suNny'
WHERE team_name = 'MOUSESPORTS';
 
UPDATE Team
SET p1_ign ='Edward', p2_ign ='electronic', p3_ign ='flamie', p4_ign ='s1mple', p5_ign ='Zeus'
WHERE team_name = 'NATUS VINCERE';
 
UPDATE Team
SET p1_ign ='balblna', p2_ign ='Boombl4', p3_ign ='jmqa', p4_ign ='Kvik', p5_ign ='waterfaLLZ'
WHERE team_name = 'QB FIRE';
 
UPDATE Team
SET p1_ign ='apEX', p2_ign ='bodyy', p3_ign ='KennyS', p4_ign ='NBK', p5_ign ='shox'
WHERE team_name = 'G2 ESPORTS';
 
UPDATE Team
SET p1_ign ='autimatic', p2_ign ='RUSH', p3_ign ='Skadoodle', p4_ign ='Stewie2K', p5_ign ='tarik'
WHERE team_name = 'CLOUD9';
 
UPDATE Team
SET p1_ign ='coldzera', p2_ign ='Fallen', p3_ign ='felps', p4_ign ='fer', p5_ign ='TACO'
WHERE team_name = 'SK GAMING';
 
UPDATE Team
SET p1_ign ='flusha', p2_ign ='Golden', p3_ign ='JW', p4_ign ='KRIMZ', p5_ign ='Lekr0'
WHERE team_name = 'FNATIC';
 
INSERT INTO Matches VALUES (1,'NUKE','FAZE',6,9,19,'MOUSESPORTS',9,6,16,1);
INSERT INTO Matches VALUES (2,'CACHE','MOUSESPORTS',5,4,9,'FAZE',10,6,16,2);
 
INSERT INTO Matches VALUES (3,'MIRAGE','NATUS VINCERE',13,3,16,'QB FIRE',2,2,4,1);
INSERT INTO Matches VALUES (4,'INFERNO','QB FIRE',4,3,7,'FAZE',11,5,16,2);
 
INSERT INTO Matches VALUES (5,'MIRAGE','G2 ESPORTS',7,1,8,'CLOUD9',8,8,16,1);
INSERT INTO Matches VALUES (6,'OVERPASS','CLOUD9',12,4,16,'G2 ESPORTS',3,4,7,2);
 
INSERT INTO Matches VALUES (7,'INFERNO','SK GAMING',6,9,19,'FNATIC',9,6,22,1);
INSERT INTO Matches VALUES (8,'OVERPASS','FNATIC',6,8,14,'SK GAMING',9,7,16,2);
INSERT INTO Matches VALUES (9,'MIRAGE','SK GAMING',7,9,16,'FNATIC',8,4,12,3);
 
INSERT INTO Matches VALUES (10,'INFERNO','FAZE',8,8,16,'NATUS VINCERE',7,2,9,1);
INSERT INTO Matches VALUES (11,'MIRAGE','NATUS VINCERE',5,2,7,'FAZE',10,6,16,2);
 
INSERT INTO Matches VALUES (12,'MIRAGE','SK GAMING',2,1,3,'CLOUD9',13,3,16,1);
INSERT INTO Matches VALUES (13,'COBBLESTONE','CLOUD9',7,1,8,'SK GAMING',8,8,16,2);
INSERT INTO Matches VALUES (14,'INFERNO','CLOUD9',12,4,16,'SK GAMING',3,6,9,3);
 
INSERT INTO Matches VALUES (15,'MIRAGE','FAZE',6,10,16,'CLOUD9',9,5,14,1);
INSERT INTO Matches VALUES (16,'INFERNO','FAZE',8,7,19,'CLOUD9',7,8,22,3);
INSERT INTO Matches VALUES (17,'OVERPASS','CLOUD9',12,4,16,'FAZE',3,7,10,2);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (1, 'Niko', 'FAZE', 36, 24, 8, 106.2, 44);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (1, 'olofmeister', 'FAZE', 27, 23, 4, 78.5, 37);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (1, 'Rain', 'FAZE', 23, 28, 7, 74.5, 61);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (1, 'GuardiaN', 'FAZE', 21, 21, 7, 64.3, 19);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (1, 'karrigan', 'FAZE', 13, 27, 4, 45.8, 46);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (1, 'suNny', 'MOUSESPORTS', 40, 20, 3, 102.9, 40);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (1, 'ropz', 'MOUSESPORTS', 27, 24, 4, 90.0, 52);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (1, 'oskar', 'MOUSESPORTS', 18, 26, 7, 67.0, 39);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (1, 'chrisJ', 'MOUSESPORTS', 18, 24, 8, 61.4, 28);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (1, 'STYKO', 'MOUSESPORTS', 20, 27, 3, 68.6, 55);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (2, 'Niko', 'FAZE', 24, 12, 6, 108.4, 54);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (2, 'olofmeister', 'FAZE', 19, 12, 5, 81.6, 53);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (2, 'GuardiaN', 'FAZE', 19, 10, 5, 61.6, 26);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (2, 'Rain', 'FAZE', 20, 14, 4, 86.8, 35);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (2, 'karrigan', 'FAZE', 15, 13, 7, 65.5, 40);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (2, 'ropz', 'MOUSESPORTS', 18, 19, 5, 81.0, 56);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (2, 'suNny', 'MOUSESPORTS', 15, 20, 3, 67.2 , 40);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (2, 'STYKO', 'MOUSESPORTS', 14, 20, 4, 66.5, 58);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (2, 'oskar', 'MOUSESPORTS', 8, 17, 5, 34.3, 13);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (2, 'chrisJ', 'MOUSESPORTS', 6, 21, 2, 39.0, 67);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (3, 'flamie', 'NATUS VINCERE', 39, 8, 2, 180.4, 46);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (3, 'electronic', 'NATUS VINCERE', 16, 12, 6, 95.3, 44);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (3, 's1mple', 'NATUS VINCERE', 16, 10, 2, 67.6, 31);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (3, 'Edward', 'NATUS VINCERE', 8, 10, 4, 65.1, 38);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (3, 'Zeus', 'NATUS VINCERE', 7, 8, 5, 45.1, 29);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (3, 'Kvik', 'QB FIRE', 14, 17, 1, 71.6, 71);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (3, 'Boombl4', 'QB FIRE', 15, 17, 4, 72.9, 67);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (3, 'balblna', 'QB FIRE', 7, 18, 3, 61.9, 43);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (3, 'waterfaLLZ', 'QB FIRE', 7, 17, 6, 61.1, 48);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (3, 'jmqa', 'QB FIRE', 5, 17, 2, 48.5, 60);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (4, 'Edward', 'NATUS VINCERE', 23, 11, 2, 103.9, 30);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (4, 'electronic', 'NATUS VINCERE', 22, 12, 2, 95.8, 64);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (4, 'flamie', 'NATUS VINCERE', 20, 13, 5, 92.0, 55);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (4, 'Zeus', 'NATUS VINCERE', 15, 11, 4, 74.3, 33);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (4, 's1mple', 'NATUS VINCERE', 11, 12, 4, 56.3, 55);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (4, 'waterfaLLZ', 'QB FIRE', 16, 19, 1, 70.9, 19);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (4, 'jmqa', 'QB FIRE', 13, 19, 2, 72.6, 38);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (4, 'Boombl4', 'QB FIRE', 10, 18, 7, 58.9, 60);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (4, 'Kvik', 'QB FIRE', 10, 16, 1, 51.6, 30);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (4, 'balblna', 'QB FIRE', 10, 19, 3, 53.8, 50);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (5, 'shox', 'G2 ESPORTS', 21, 20, 2, 84.2, 48);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (5, 'apEX', 'G2 ESPORTS', 19, 18, 7, 82.3, 68);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (5, 'KennyS', 'G2 ESPORTS', 12, 18, 1, 54.8, 42);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (5, 'bodyy', 'G2 ESPORTS', 8, 19, 3, 46.7, 50);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (5, 'NBK', 'G2 ESPORTS', 10, 18, 1, 50.9, 30);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (5, 'RUSH', 'CLOUD9', 26, 13, 4, 111.0, 42);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (5, 'Stewie2K', 'CLOUD9', 18, 17, 5, 90.9, 67);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (5, 'Skadoodle', 'CLOUD9', 17, 11, 4, 59.8, 24);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (5, 'tarik', 'CLOUD9', 16, 13, 2, 71.8, 44);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (5, 'autimatic', 'CLOUD9', 16, 16, 0, 67.9, 69);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (6, 'bodyy', 'G2 ESPORTS', 19, 15, 3, 86.8, 53);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (6, 'KennyS', 'G2 ESPORTS', 14, 16, 4, 70.2,29);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (6, 'shox', 'G2 ESPORTS', 16, 18, 0, 67.5, 38);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (6, 'NBK', 'G2 ESPORTS', 14, 18, 2, 68.0, 57);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (6, 'apEX', 'G2 ESPORTS', 7, 21, 5, 49.5, 57);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (6, 'tarik', 'CLOUD9', 22, 17, 8, 105.4, 32);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (6, 'autimatic', 'CLOUD9',18, 14, 4, 67.0, 22);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (6, 'RUSH', 'CLOUD9', 14, 10, 6, 75.1, 36);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (6, 'Stewie2K', 'CLOUD9', 20, 16, 4, 87.4, 40);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (6, 'Skadoodle', 'CLOUD9', 14, 13, 8, 72.7, 7);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (7, 'TACO', 'SK GAMING', 32, 28, 6, 85.3, 47);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (7, 'coldzera', 'SK GAMING', 31, 31, 7, 89.2, 52);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (7, 'Fallen', 'SK GAMING', 31, 30, 8, 74.2, 26);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (7, 'fer', 'SK GAMING', 24, 30, 6, 66.1, 63);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (7, 'felps', 'SK GAMING', 16, 33, 12, 65.4, 50);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (7, 'flusha', 'FNATIC', 38, 24, 8, 109.0, 55);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (7, 'Lekr0', 'FNATIC', 34, 28, 5, 86.5, 53);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (7, 'KRIMZ', 'FNATIC', 33, 28, 4, 81.7, 30);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (7, 'Golden', 'FNATIC', 21, 25, 4, 57.1, 29);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (7, 'JW', 'FNATIC', 26, 30, 5, 65.0, 42);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (8, 'felps', 'SK GAMING', 25, 19, 3, 85.1, 48);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (8, 'Fallen', 'SK GAMING', 21, 22, 9, 81.8, 14);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (8, 'TACO', 'SK GAMING', 21, 22, 6, 75.6, 67);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (8, 'coldzera', 'SK GAMING', 22, 18, 3, 66.3, 64);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (8, 'fer', 'SK GAMING', 16, 23, 9, 70.1, 56);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (8, 'KRIMZ', 'FNATIC', 27, 17, 3, 91.4, 37);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (8, 'Lekr0', 'FNATIC', 28, 22, 1, 80.7, 54);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (8, 'JW', 'FNATIC', 21, 22, 5, 89.2, 57);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (8, 'flusha', 'FNATIC', 15, 20, 5,  64.1, 33);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (8, 'Golden', 'FNATIC', 13, 24, 5, 59.7, 54);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (9, 'fer', 'SK GAMING', 23, 17, 4, 87.3, 52);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (9, 'coldzera', 'SK GAMING', 20, 14, 3, 84.1, 40);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (9, 'Fallen', 'SK GAMING', 21, 15, 3, 76.2, 33);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (9, 'felps', 'SK GAMING', 16, 19, 6, 76.2, 75);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (9, 'TACO', 'SK GAMING', 12, 17, 2, 56.5, 75);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (9, 'Lekr0', 'FNATIC', 23, 19, 6, 96.2, 61);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (9, 'Golden', 'FNATIC', 20, 16, 2, 72.7, 50);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (9, 'JW', 'FNATIC', 19, 17, 4, 77.1, 26);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (9, 'KRIMZ', 'FNATIC', 12, 19, 3, 48.1, 42);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (9, 'flusha', 'FNATIC', 8, 21, 2, 48.3, 38);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (10, 'Niko', 'FAZE', 24, 13, 7, 119.2, 67);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (10, 'karrigan', 'FAZE', 23, 14, 3, 70.6, 26);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (10, 'Rain', 'FAZE', 16, 17, 12, 94.2, 44);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (10, 'GuardiaN', 'FAZE', 20, 16, 7, 73.7, 30);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (10, 'olofmeister', 'FAZE', 17, 15, 4, 72.1, 35);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (10, 'flamie', 'NATUS VINCERE', 22, 22, 3, 90.0, 36);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (10, 's1mple', 'NATUS VINCERE', 17, 22, 8, 78.4, 18);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (10, 'electronic', 'NATUS VINCERE', 17, 18, 7, 66.4, 36);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (10, 'Edward', 'NATUS VINCERE', 10, 18, 4, 55.2, 30);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (10, 'Zeus', 'NATUS VINCERE', 9, 20, 5, 55.7, 44);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (11, 'Rain', 'FAZE', 21, 13, 4, 108.9, 67);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (11, 'olofmeister', 'FAZE', 23, 15, 1, 87.0, 39);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (11, 'GuardiaN', 'FAZE', 19, 11, 2, 73.2, 21);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (11, 'Niko', 'FAZE', 19, 10, 3, 76.9, 68);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (11, 'karrigan', 'FAZE', 9, 15, 8, 56.8, 44);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (11, 's1mple', 'NATUS VINCERE', 23, 17, 3, 93.7, 52);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (11, 'Zeus', 'NATUS VINCERE', 14, 18, 6, 71.4, 36);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (11, 'Edward', 'NATUS VINCERE', 11, 19, 7, 64.5, 36);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (11, 'electronic', 'NATUS VINCERE', 9, 19, 2, 57.9, 44);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (11, 'flamie', 'NATUS VINCERE', 7, 18, 4, 44.0, 29);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (12, 'Skadoodle', 'CLOUD9', 21, 8, 3, 107.7, 19);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (12, 'autimatic', 'CLOUD9', 18, 8, 2, 84.6, 44);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (12, 'RUSH', 'CLOUD9', 14, 8, 5, 87.2, 93);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (12, 'tarik', 'CLOUD9', 13, 12, 6, 87.3, 38);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (12, 'Stewie2K', 'CLOUD9', 14, 14, 3, 80.4, 21);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (12, 'coldzera', 'SK GAMING', 14, 12, 1, 70.4, 57);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (12, 'TACO', 'SK GAMING', 9, 17, 4, 72.0, 55);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (12, 'Fallen', 'SK GAMING', 10, 17, 0, 57.5, 40);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (12, 'fer', 'SK GAMING', 8, 17, 3, 54.5, 25);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (12, 'felps', 'SK GAMING', 8, 17, 1, 48.4, 25);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (13, 'Stewie2K', 'CLOUD9', 19, 18, 3, 91.7, 53);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (13, 'autimatic', 'CLOUD9', 18, 18, 1, 81.1, 39);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (13, 'tarik', 'CLOUD9', 16, 20, 3, 73.5, 38);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (13, 'RUSH', 'CLOUD9', 12, 20, 3, 61.8, 17);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (13, 'Skadoodle', 'CLOUD9', 8, 17, 4, 40.3, 38);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (13, 'fer', 'SK GAMING', 27, 13, 4, 113.8, 30);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (13, 'TACO', 'SK GAMING', 21, 15, 4, 91.2, 33);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (13, 'coldzera', 'SK GAMING', 17, 13, 4, 56.2, 53);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (13, 'Fallen', 'SK GAMING', 15, 17, 9, 90.5, 53);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (13, 'felps', 'SK GAMING', 13, 15, 4, 73.5, 23);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (14, 'tarik', 'CLOUD9', 26, 16, 8, 121.0, 46);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (14, 'autimatic', 'CLOUD9', 22, 14, 5, 87.1, 36);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (14, 'RUSH', 'CLOUD9', 18, 12, 5, 93.5, 39);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (14, 'Stewie2K', 'CLOUD9', 16, 12, 1, 53.8, 25);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (14, 'Skadoodle', 'CLOUD9', 14, 16, 7, 57.6, 29);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (14, 'coldzera', 'SK GAMING', 16, 17, 6, 70.9, 56);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (14, 'felps', 'SK GAMING', 17, 23, 3, 84.7, 56);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (14, 'fer', 'SK GAMING', 13, 19, 5, 68.4, 46);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (14, 'Fallen', 'SK GAMING', 14, 17, 3, 55.0, 21);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (14, 'TACO', 'SK GAMING', 14, 20, 1, 45.8, 57);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (15, 'Rain', 'FAZE', 24, 21, 4, 85.7, 67);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (15, 'olofmeister', 'FAZE', 25, 20, 4, 92.5, 52);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (15, 'GuardiaN', 'FAZE', 26, 19, 1, 83.9, 23);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (15, 'karrigan', 'FAZE', 12, 18, 6, 56.8, 58);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (15, 'Niko', 'FAZE', 12, 23, 6, 51.4, 58);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (15, 'Skadoodle', 'CLOUD9', 27, 16, 3, 92.4, 11);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (15, 'autimatic', 'CLOUD9', 24, 20, 4, 79.6, 71);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (15, 'RUSH', 'CLOUD9', 21, 18, 1, 67.6, 57);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (15, 'tarik', 'CLOUD9', 17, 24, 6, 68.4, 41);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (15, 'Stewie2K', 'CLOUD9', 12, 21, 4, 55.8, 92);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (16, 'Rain', 'FAZE', 22, 21, 5, 100.2, 41);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (16, 'GuardiaN', 'FAZE', 20, 19, 6, 79.2, 35);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (16, 'Niko', 'FAZE', 16, 20, 5, 72.4, 56);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (16, 'olofmeister', 'FAZE', 12, 19, 4, 52.3, 50);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (16, 'karrigan', 'FAZE', 9, 20, 3, 42.3, 33);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (16, 'tarik', 'CLOUD9',22, 15, 6, 101.2, 27);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (16, 'Skadoodle', 'CLOUD9', 21, 16, 6, 83.2, 29);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (16, 'autimatic', 'CLOUD9', 21, 14, 3, 78.9, 14);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (16, 'Stewie2K', 'CLOUD9', 21, 17, 4, 85.2, 38);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (16, 'RUSH', 'CLOUD9', 14, 17, 4, 52.5, 64);
 
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (17, 'Niko', 'FAZE', 28, 28, 12, 77.3, 39);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (17, 'olofmeister', 'FAZE', 27, 31, 6, 75.1, 48);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (17, 'GuardiaN', 'FAZE', 29, 28, 6, 67.2, 28);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (17, 'karrigan', 'FAZE', 26, 32, 4, 69.9, 27);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (17, 'Rain', 'FAZE', 17, 30, 6, 53.2, 47);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (17, 'tarik', 'CLOUD9', 38, 25, 7, 92.1, 34);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (17, 'Stewie2K', 'CLOUD9', 32, 29, 6, 86.5, 47);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (17, 'Skadoodle', 'CLOUD9', 31,23, 6, 71.1, 10);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (17, 'autimatic', 'CLOUD9', 30, 26, 10, 80.3, 37);
INSERT INTO Player_Statistics (match, in_game_name, team_name, Kills, Deaths, Assists, ADR, HS_Percentage) VALUES (17, 'RUSH', 'CLOUD9', 18, 24, 14, 62.8, 44);