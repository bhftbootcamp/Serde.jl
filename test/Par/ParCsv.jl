# Par/ParCsv

@testset verbose = true "ParCsv" begin
    @testset "Case №1: Normal csv" begin
        source = """
        "last_name", "first_name", "ssn",        "test1", "test2", "test3", "test4", "final", "grade"
        "Alfalfa",   "Aloysius",   "123-45-6789", 40.0,    90.0,   100.0,    83.0,    49.0,   "D-"
        "Alfred",    "University", "123-12-1234", 41.0,    97.0,    96.0,    97.0,    48.0,   "D+"
        "Gerty",     "Gramma",     "567-89-0123", 41.0,    80.0,    60.0,    40.0,    44.0,   "C"
        "Android",   "Electric",   "087-65-4321", 42.0,    23.0,    36.0,    45.0,    47.0,   "B-"
        "Bumpkin",   "Fred",       "456-78-9012", 43.0,    78.0,    88.0,    77.0,    45.0,   "A-"
        "Rubble",    "Betty",      "234-56-7890", 44.0,    90.0,    80.0,    90.0,    46.0,   "C-"
        "Noshow",    "Cecil",      "345-67-8901", 45.0,    11.0,    -1.0,     4.0,    43.0,   "F"
        "Buff",      "Bif",        "632-79-9939", 46.0,    20.0,    30.0,    40.0,    50.0,   "B+"
        "Airpump",   "Andrew",     "223-45-6789", 49.0,      1.0,    90.0,   100.0,    83.0,   "A"
        "Backus",    "Jim",        "143-12-1234", 48.0,     1.0,    97.0,    96.0,    97.0,   "A+"
        "Carnivore", "Art",        "565-89-0123", 44.0,     1.0,    80.0,    60.0,    40.0,   "D+"
        "Dandy",     "Jim",        "087-75-4321", 47.0,     1.0,    23.0,    36.0,    45.0,   "C+"
        "Elephant",  "Ima",        "456-71-9012", 45.0,     1.0,    78.0,    88.0,    77.0,   "B-"
        "Franklin",  "Benny",      "234-56-2890", 50.0,     1.0,    90.0,    80.0,    90.0,   "B-"
        "George",    "Boy",        "345-67-3901", 40.0,     1.0,    11.0,    -1.0,     4.0,   "B"
        "Heffalump", "Harvey",     "632-79-9439", 30.0,     1.0,    20.0,    30.0,    40.0,   "C"\
        """
        parsed = NamedTuple{
            (:last_name, :first_name, :ssn, :test1, :test2, :test3, :test4, :final, :grade),
            NTuple{9,String},
        }[
            (
                last_name = "Alfalfa",
                first_name = "Aloysius",
                ssn = "123-45-6789",
                test1 = " 40.0",
                test2 = "    90.0",
                test3 = "   100.0",
                test4 = "    83.0",
                final = "    49.0",
                grade = "D-",
            ),
            (
                last_name = "Alfred",
                first_name = "University",
                ssn = "123-12-1234",
                test1 = " 41.0",
                test2 = "    97.0",
                test3 = "    96.0",
                test4 = "    97.0",
                final = "    48.0",
                grade = "D+",
            ),
            (
                last_name = "Gerty",
                first_name = "Gramma",
                ssn = "567-89-0123",
                test1 = " 41.0",
                test2 = "    80.0",
                test3 = "    60.0",
                test4 = "    40.0",
                final = "    44.0",
                grade = "C",
            ),
            (
                last_name = "Android",
                first_name = "Electric",
                ssn = "087-65-4321",
                test1 = " 42.0",
                test2 = "    23.0",
                test3 = "    36.0",
                test4 = "    45.0",
                final = "    47.0",
                grade = "B-",
            ),
            (
                last_name = "Bumpkin",
                first_name = "Fred",
                ssn = "456-78-9012",
                test1 = " 43.0",
                test2 = "    78.0",
                test3 = "    88.0",
                test4 = "    77.0",
                final = "    45.0",
                grade = "A-",
            ),
            (
                last_name = "Rubble",
                first_name = "Betty",
                ssn = "234-56-7890",
                test1 = " 44.0",
                test2 = "    90.0",
                test3 = "    80.0",
                test4 = "    90.0",
                final = "    46.0",
                grade = "C-",
            ),
            (
                last_name = "Noshow",
                first_name = "Cecil",
                ssn = "345-67-8901",
                test1 = " 45.0",
                test2 = "    11.0",
                test3 = "    -1.0",
                test4 = "     4.0",
                final = "    43.0",
                grade = "F",
            ),
            (
                last_name = "Buff",
                first_name = "Bif",
                ssn = "632-79-9939",
                test1 = " 46.0",
                test2 = "    20.0",
                test3 = "    30.0",
                test4 = "    40.0",
                final = "    50.0",
                grade = "B+",
            ),
            (
                last_name = "Airpump",
                first_name = "Andrew",
                ssn = "223-45-6789",
                test1 = " 49.0",
                test2 = "      1.0",
                test3 = "    90.0",
                test4 = "   100.0",
                final = "    83.0",
                grade = "A",
            ),
            (
                last_name = "Backus",
                first_name = "Jim",
                ssn = "143-12-1234",
                test1 = " 48.0",
                test2 = "     1.0",
                test3 = "    97.0",
                test4 = "    96.0",
                final = "    97.0",
                grade = "A+",
            ),
            (
                last_name = "Carnivore",
                first_name = "Art",
                ssn = "565-89-0123",
                test1 = " 44.0",
                test2 = "     1.0",
                test3 = "    80.0",
                test4 = "    60.0",
                final = "    40.0",
                grade = "D+",
            ),
            (
                last_name = "Dandy",
                first_name = "Jim",
                ssn = "087-75-4321",
                test1 = " 47.0",
                test2 = "     1.0",
                test3 = "    23.0",
                test4 = "    36.0",
                final = "    45.0",
                grade = "C+",
            ),
            (
                last_name = "Elephant",
                first_name = "Ima",
                ssn = "456-71-9012",
                test1 = " 45.0",
                test2 = "     1.0",
                test3 = "    78.0",
                test4 = "    88.0",
                final = "    77.0",
                grade = "B-",
            ),
            (
                last_name = "Franklin",
                first_name = "Benny",
                ssn = "234-56-2890",
                test1 = " 50.0",
                test2 = "     1.0",
                test3 = "    90.0",
                test4 = "    80.0",
                final = "    90.0",
                grade = "B-",
            ),
            (
                last_name = "George",
                first_name = "Boy",
                ssn = "345-67-3901",
                test1 = " 40.0",
                test2 = "     1.0",
                test3 = "    11.0",
                test4 = "    -1.0",
                final = "     4.0",
                grade = "B",
            ),
            (
                last_name = "Heffalump",
                first_name = "Harvey",
                ssn = "632-79-9439",
                test1 = " 30.0",
                test2 = "     1.0",
                test3 = "    20.0",
                test4 = "    30.0",
                final = "    40.0",
                grade = "C",
            ),
        ]
        @test Serde.parse_csv(source) == parsed
    end

    @testset "Case №2: Exceptions tests" begin
        source = """
        "last_name" "first_name" "ssn"        "test1" "test2" "test3" "test4" "final" "grade"
        "Alfalfa"   "Aloysius"  "123-45-6789" 40.0    90.0   100.0    83.0    49.0   "D-"
        "Alfred"    "University" "123-12-1234" 41.0    97.0    96.0    97.0    48.0   "D+"
        "Gerty"     "Gramma"     "567-89-0123" 41.0    80.0    60.0    40.0    44.0   "C"
        "Android"   "Electric"   "087-65-4321" 42.0    23.0    36.0    45.0    47.0   "B-"
        "Bumpkin"   "Fred"       "456-78-9012" 43.0    78.0    88.0    77.0    45.0   "A-"
        "Rubble"    "Betty"      "234-56-7890" 44.0    90.0    80.0    90.0    46.0   "C-"
        "Noshow"    "Cecil"      "345-67-8901" 45.0    11.0    -1.0     4.0    43.0   "F"
        "Buff"      "Bif"        "632-79-9939" 46.0    20.0    30.0    40.0    50.0   "B+"
        "Airpump"   "Andrew"     "223-45-6789" 49.0      1.0    90.0   100.0    83.0   "A"
        "Backus"    "Jim"        "143-12-1234" 48.0     1.0    97.0    96.0    97.0   "A+"
        "Carnivore" "Art"        "565-89-0123" 44.0     1.0    80.0    60.0    40.0   "D+"
        "Dandy"     "Jim"        "087-75-4321" 47.0     1.0    23.0    36.0    45.0   "C+"
        "Elephant"  "Ima"        "456-71-9012" 45.0     1.0    78.0    88.0    77.0   "B-"
        "Franklin"  "Benny"      "234-56-2890" 50.0     1.0    90.0    80.0    90.0   "B-"
        "George"    "Boy"        "345-67-3901" 40.0     1.0    11.0    -1.0     4.0   "B"
        "Heffalump" "Harvey"     "632-79-9439" 30.0     1.0    20.0    30.0    40.0   "C"\
        """
        @test_throws Serde.ParCsv.CSVSyntaxError Serde.parse_csv(source)
    end
end
