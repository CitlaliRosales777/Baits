-- Esquema para una instalación nueva de APIcore, basado en api-citas (1b2b419).
CREATE DATABASE IF NOT EXISTS apicore CHARACTER SET utf8 COLLATE utf8_general_ci;
USE apicore;

CREATE TABLE IF NOT EXISTS moods (
    MoodId INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    MoodName VARCHAR(16) NOT NULL,
    MoodStatus ENUM('Active','Inactive') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `example` (
    ExampleId INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    ExampleName VARCHAR(45) NOT NULL,
    ExampleCode CHAR(3) DEFAULT NULL,
    ExampleDescription TEXT,
    ExamplePrice DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    ExampleQuantity INT NOT NULL DEFAULT 0,
    ExampleBigNumber BIGINT NOT NULL DEFAULT 0,
    ExampleRatio FLOAT NOT NULL DEFAULT 0,
    ExampleActive TINYINT(1) NOT NULL DEFAULT 1,
    ExampleStatus ENUM('Active','Inactive') NOT NULL DEFAULT 'Active',
    ExampleBirthDate DATE DEFAULT NULL,
    ExampleCreatedAt DATETIME DEFAULT NULL,
    ExampleStartTime TIME DEFAULT NULL,
    ExampleYear YEAR DEFAULT NULL,
    ExampleMetadata JSON DEFAULT NULL,
    ExamplePicture BLOB
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS users (
    UserId INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    Username VARCHAR(16) NOT NULL,
    Password VARCHAR(255) NOT NULL,
    Name VARCHAR(45) NOT NULL,
    PaternalSurname VARCHAR(25) NOT NULL,
    MaternalSurname VARCHAR(25) DEFAULT NULL,
    Email VARCHAR(100) DEFAULT NULL,
    BirthDate DATE DEFAULT NULL,
    Phone VARCHAR(15) DEFAULT NULL,
    EmergencyPhone VARCHAR(15) DEFAULT NULL,
    UserStatus ENUM('Active','Inactive') NOT NULL,
    UserRole ENUM('God','Admin','User','Other') NOT NULL DEFAULT 'User',
    UNIQUE KEY Username (Username),
    UNIQUE KEY Email (Email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS users_tokens (
    TokenId INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    UserId INT UNSIGNED NOT NULL,
    TokenHash VARCHAR(255) NOT NULL,
    TokenExpiration DATETIME NOT NULL,
    TokenCreatedAt DATETIME NOT NULL,
    UNIQUE KEY TokenHash (TokenHash),
    KEY UserId (UserId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
