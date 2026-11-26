using System;

namespace PlayerCareer.Core
{
    /// <summary>Shared player data types with no dependency on a game engine.</summary>
    public enum PlayerPosition
    {
        Goalkeeper,
        Defender,
        Midfielder,
        Forward
    }

    public enum PreferredFoot
    {
        Left,
        Right,
        Both
    }

    /// <summary>Outfield attributes use the agreed 1–100 scale.</summary>
    public sealed class PlayerAttributes
    {
        public int Speed { get; }
        public int Acceleration { get; }
        public int Stamina { get; }
        public int Strength { get; }
        public int Agility { get; }
        public int BallControl { get; }
        public int Dribbling { get; }
        public int ShortPassing { get; }
        public int LongPassing { get; }
        public int Shooting { get; }
        public int Heading { get; }
        public int Tackling { get; }
        public int Vision { get; }
        public int Positioning { get; }

        public PlayerAttributes(
            int speed,
            int acceleration,
            int stamina,
            int strength,
            int agility,
            int ballControl,
            int dribbling,
            int shortPassing,
            int longPassing,
            int shooting,
            int heading,
            int tackling,
            int vision,
            int positioning)
        {
            Speed = Rating(speed, nameof(speed));
            Acceleration = Rating(acceleration, nameof(acceleration));
            Stamina = Rating(stamina, nameof(stamina));
            Strength = Rating(strength, nameof(strength));
            Agility = Rating(agility, nameof(agility));
            BallControl = Rating(ballControl, nameof(ballControl));
            Dribbling = Rating(dribbling, nameof(dribbling));
            ShortPassing = Rating(shortPassing, nameof(shortPassing));
            LongPassing = Rating(longPassing, nameof(longPassing));
            Shooting = Rating(shooting, nameof(shooting));
            Heading = Rating(heading, nameof(heading));
            Tackling = Rating(tackling, nameof(tackling));
            Vision = Rating(vision, nameof(vision));
            Positioning = Rating(positioning, nameof(positioning));
        }

        private static int Rating(int value, string name)
        {
            if (value < 1 || value > 100)
                throw new ArgumentOutOfRangeException(name, value, "Player attributes must be between 1 and 100.");

            return value;
        }
    }

    /// <summary>Goalkeeper-specific attributes use the same 1–100 scale.</summary>
    public sealed class GoalkeeperAttributes
    {
        public int Reflexes { get; }
        public int ShotStopping { get; }
        public int Handling { get; }
        public int Distribution { get; }

        public GoalkeeperAttributes(int reflexes, int shotStopping, int handling, int distribution)
        {
            Reflexes = Rating(reflexes, nameof(reflexes));
            ShotStopping = Rating(shotStopping, nameof(shotStopping));
            Handling = Rating(handling, nameof(handling));
            Distribution = Rating(distribution, nameof(distribution));
        }

        private static int Rating(int value, string name)
        {
            if (value < 1 || value > 100)
                throw new ArgumentOutOfRangeException(name, value, "Goalkeeper attributes must be between 1 and 100.");

            return value;
        }
    }

    /// <summary>Personality tendencies are separate from football skill ratings; 0–100 is a provisional scale.</summary>
    public sealed class PersonalityProfile
    {
        public int Professionalism { get; }
        public int Teamwork { get; }
        public int Confidence { get; }
        public int Discipline { get; }
        public int Resilience { get; }

        public PersonalityProfile(int professionalism, int teamwork, int confidence, int discipline, int resilience)
        {
            Professionalism = Trait(professionalism, nameof(professionalism));
            Teamwork = Trait(teamwork, nameof(teamwork));
            Confidence = Trait(confidence, nameof(confidence));
            Discipline = Trait(discipline, nameof(discipline));
            Resilience = Trait(resilience, nameof(resilience));
        }

        private static int Trait(int value, string name)
        {
            if (value < 0 || value > 100)
                throw new ArgumentOutOfRangeException(name, value, "Personality values must be between 0 and 100.");

            return value;
        }
    }

    /// <summary>Identity and core ratings for a created career player.</summary>
    public sealed class CareerPlayer
    {
        public string Name { get; }
        public string NationalityCode { get; }
        public int Age { get; }
        public PlayerPosition MainPosition { get; }
        public PreferredFoot PreferredFoot { get; }
        public PlayerAttributes Attributes { get; }
        public GoalkeeperAttributes? GoalkeeperAttributes { get; }
        public PersonalityProfile Personality { get; }

        public CareerPlayer(
            string name,
            string nationalityCode,
            int age,
            PlayerPosition mainPosition,
            PreferredFoot preferredFoot,
            PlayerAttributes attributes,
            PersonalityProfile personality,
            GoalkeeperAttributes? goalkeeperAttributes = null)
        {
            if (string.IsNullOrWhiteSpace(name))
                throw new ArgumentException("A player name is required.", nameof(name));
            if (string.IsNullOrWhiteSpace(nationalityCode))
                throw new ArgumentException("A nationality code is required.", nameof(nationalityCode));
            if (age < 15)
                throw new ArgumentOutOfRangeException(nameof(age), age, "Career players start at age 15 or older.");
            if (mainPosition == PlayerPosition.Goalkeeper && goalkeeperAttributes == null)
                throw new ArgumentException("Goalkeepers need goalkeeper-specific attributes.", nameof(goalkeeperAttributes));

            Name = name.Trim();
            NationalityCode = nationalityCode.Trim().ToUpperInvariant();
            Age = age;
            MainPosition = mainPosition;
            PreferredFoot = preferredFoot;
            Attributes = attributes ?? throw new ArgumentNullException(nameof(attributes));
            Personality = personality ?? throw new ArgumentNullException(nameof(personality));
            GoalkeeperAttributes = goalkeeperAttributes;
        }
    }
}
