defmodule AbsintheConstraints.Integration.APITest do
  use ExUnit.Case, async: true

  describe "constraints should validate API inputs" do
    defmodule TestSchema do
      use Absinthe.Schema

      @prototype_schema AbsintheConstraints.Directive

      input_object :input_object do
        field(:id, :string, directives: [constraints: [format: "uuid"]])
        field(:user_id, :id, directives: [constraints: [format: "uuid"]])
      end

      query do
        field :test, non_null(:string) do
          arg(:list, non_null(list_of(non_null(:integer))),
            directives: [constraints: [min_items: 2]]
          )

          arg(:number, :integer, directives: [constraints: [min: 2]])

          arg(:regex_field, non_null(:string),
            directives: [constraints: [pattern: "^[A-Z][0-9a-z]*$"]]
          )

          arg(:id, non_null(:id), directives: [constraints: [format: "uuid"]])

          resolve(fn _, _ -> {:ok, "test_result"} end)
        end
      end

      mutation do
        field(:do_something, :string) do
          arg(:id, non_null(:string), directives: [constraints: [format: "uuid"]])

          arg(:user_id, non_null(:id),
            directives: [constraints: [format: "uuid", min_length: 36]]
          )

          arg(:id_obj, non_null(:input_object))

          resolve(fn _, _ -> {:ok, "ok"} end)
        end
      end

      def run_query(query),
        do:
          Absinthe.run(
            query,
            __MODULE__,
            pipeline_modifier: &AbsintheConstraints.Phase.add_to_pipeline/2
          )
    end

    test "should return success on valid query arguments" do
      assert {:ok, %{data: %{"test" => "test_result"}}} ==
               TestSchema.run_query(
                 "{ test(list: [1, 3],id: \"EBDB3717-5E22-4A76-8672-72F4C6D042C9\", number: 5, regexField: \"A123aa\") }"
               )
    end

    test "should return errors on invalid query arguments" do
      assert {:ok,
              %{
                errors: [
                  %{
                    message: "\"list\" must have at least 2 items",
                    locations: [%{line: 1, column: 8}]
                  },
                  %{
                    message: "\"number\" must be greater than or equal to 2",
                    locations: [%{line: 1, column: 19}]
                  },
                  %{
                    message: "\"regexField\" must match regular expression `^[A-Z][0-9a-z]*$`",
                    locations: [%{line: 1, column: 30}]
                  },
                  %{
                    message: "\"id\" must be a valid UUID",
                    locations: [%{line: 1, column: 53}]
                  }
                ]
              }} ==
               TestSchema.run_query(
                 "{ test(list: [1], number: 1, regexField: \"invalid\", id: \"invalid uuid\")}"
               )
    end

    test "should return errors on valid mutation arguments" do
      assert {:ok, %{data: %{"do_something" => "ok"}}} ==
               TestSchema.run_query(
                 "mutation { do_something(id: \"6C20BCCA-9396-452B-99AB-F2C168CA7A58\", userId: \"2B761BD3-13F5-407B-84DC-F8F8B7227CD5\",  id_obj: {id: \"52316597-7194-4ABE-8152-B43C0E6CD43E\"}) }"
               )
    end

    test "should return errors on invalid mutation arguments" do
      assert {:ok,
              %{
                errors: [
                  %{message: "\"id\" must be a valid UUID", locations: [%{line: 1, column: 25}]},
                  %{message: "\"id\" must be a valid UUID", locations: [%{line: 1, column: 46}]},
                  %{
                    locations: [%{column: 58, line: 1}],
                    message: "\"userId\" must be at least 36 characters in length"
                  },
                  %{
                    locations: [%{column: 58, line: 1}],
                    message: "\"userId\" must be a valid UUID"
                  }
                ]
              }} ==
               TestSchema.run_query(
                 "mutation { do_something(id: \"asdf\", id_obj: {id: \"123\"}, userId: \"invalid\") }"
               )
    end
  end
end
