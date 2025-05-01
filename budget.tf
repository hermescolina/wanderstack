resource "aws_budgets_budget" "ec2_hours_budget" {
  name         = "FreeTierEC2Budget"
  budget_type  = "USAGE"
  time_unit    = "MONTHLY"
  limit_amount = "700"
  limit_unit   = "HOURS"

  cost_types {
    include_credit             = true
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = true
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_amortized              = false
    use_blended                = false
  }
}

resource "aws_budgets_budget_action" "notify_budget_exceeded" {
  budget_name      = aws_budgets_budget.ec2_hours_budget.name
  action_type      = "APPLY_IAM_POLICY"
  action_threshold {
    action_threshold_type = "PERCENTAGE"
    action_threshold_value = 100
  }

  definition {
    iam_action_definition {
      policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess" # or custom
      roles      = ["your-iam-role-name"]
    }
  }

  execution_role_arn = "arn:aws:iam::123456789012:role/YourBudgetActionRole" # Must be created

  approval_model = "AUTOMATIC"
  notification_type = "ACTUAL"

  subscriber {
    address          = "your@email.com"
    subscription_type = "EMAIL"
  }
}
