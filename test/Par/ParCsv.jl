# Par/ParCsv

@testset verbose = true "ParCsv" begin
    @testset "Case №1: Normal CSV Parsing" begin
        exp_str = """
        "last_name", "first_name", "ssn",        "test1", "test2", "test3", "test4", "final", "grade"
        "Alfalfa",   "Aloysius",   "123-45-6789", 40.0,    90.0,   100.0,    83.0,    49.0,   "D-"
        "Alfred",    "University", "123-12-1234", 41.0,    97.0,    96.0,    97.0,    48.0,   "D+"
        "Gerty",     "Gramma",     "567-89-0123", 41.0,    80.0,    60.0,    40.0,    44.0,   "C"
        "Heffalump", "Harvey",     "632-79-9439", 30.0,     1.0,    20.0,    30.0,    40.0,   "C"\
        """
        exp_obj = [
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
        @test Serde.parse_csv(exp_str) == exp_obj
        @test Serde.parse_csv(Vector{UInt8}(exp_str)) == exp_obj
        @test Serde.parse_csv(SubString(exp_str, 1)) == exp_obj

        exp_str = """
        first,last,address,city,zip
        John,Doe,120 any st.,"Anytown, WW",08123
        """
        exp_obj = [
            (
                first = "John",
                last = "Doe",
                address = "120 any st.",
                city = "Anytown, WW",
                zip = "08123",
            ),
        ]
        @test Serde.parse_csv(exp_str) == exp_obj

        exp_str = """
        a,b,c
        1,"",""
        2,3,4
        """
        exp_obj = [(a = "1", b = "", c = ""), (a = "2", b = "3", c = "4")]
        @test Serde.parse_csv(exp_str) == exp_obj

        exp_str = """
        a,b
        1,"ha ""ha"" ha"
        3,4
        """
        exp_obj = [(a = "1", b = "ha \"ha\" ha"), (a = "3", b = "4")]
        @test Serde.parse_csv(exp_str) == exp_obj

        exp_str = """
        a,b,c
        1,2,3
        "Once upon 
        a time",5,6
        7,8,9
        """
        exp_obj = [
            (a = "1", b = "2", c = "3"),
            (a = "Once upon \na time", b = "5", c = "6"),
            (a = "7", b = "8", c = "9"),
        ]
        @test Serde.parse_csv(exp_str) == exp_obj

        exp_str = """
        a,b
        1,"ha 
        ""ha"" 
        ha"
        3,4
        """
        exp_obj = [(a = "1", b = "ha \n\"ha\" \nha"), (a = "3", b = "4")]
        @test Serde.parse_csv(exp_str) == exp_obj

        exp_str = """
        a,b,c
        1,2,3
        4,5,ʤ
        """
        exp_obj = [(a = "1", b = "2", c = "3"), (a = "4", b = "5", c = "ʤ")]
        @test Serde.parse_csv(exp_str) == exp_obj

        exp_str = """
        a-b-c
        1-2-3
        4-5-6
        """
        exp_obj = [(a = "1", b = "2", c = "3"), (a = "4", b = "5", c = "6")]
        @test Serde.parse_csv(exp_str; delimiter = "-") == exp_obj
    end

    @testset "Case №2: Exception Handling in CSV Parsing" begin
        exp_str ="""
        "last_name", "first_name", "ssn",        "test1", "test2", "test3", "test4", "final", "grade"
        "Alfalfa",   "Aloysius",   "123-45-6789", 40.0,    90.0,   100.0,    83.0,    49.0,   "D-"
        "Alfred",    "University", "123-12-1234", 41.0,    97.0,    96.0,    97.0,    48.0,   "D+"
        "Gerty",     "Gramma",     "567-89-0123", 41.0,    80.0,    60.0,    40.0,    44.0,   "C"
        "Heffalump", "Harvey",     "632-79-9439", 30.0,     1.0,    20.0,    30.0,    40.0,   "C"\
        """ * "&/%"
        @test_throws Serde.ParCsv.CSVSyntaxError Serde.parse_csv(exp_str)
    end
end
