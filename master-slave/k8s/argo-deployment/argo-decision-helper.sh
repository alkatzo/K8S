#!/bin/bash

# Argo Workflows Decision Helper
# This script helps you decide whether to use Argo Workflows

echo "=================================================="
echo "Argo Workflows vs Regular Jobs - Decision Helper"
echo "=================================================="
echo ""

score=0

echo "Please answer the following questions (y/n):"
echo ""

# Question 1
read -p "1. Do you need to run jobs in parallel (fan-out/fan-in)? " q1
if [[ $q1 == "y" || $q1 == "Y" ]]; then
    score=$((score + 3))
    echo "   → +3 points for Argo Workflows"
fi

# Question 2
read -p "2. Do you need complex job dependencies (DAG)? " q2
if [[ $q2 == "y" || $q2 == "Y" ]]; then
    score=$((score + 3))
    echo "   → +3 points for Argo Workflows"
fi

# Question 3
read -p "3. Do you need conditional job execution? " q3
if [[ $q3 == "y" || $q3 == "Y" ]]; then
    score=$((score + 2))
    echo "   → +2 points for Argo Workflows"
fi

# Question 4
read -p "4. Do you need workflow visualization/monitoring? " q4
if [[ $q4 == "y" || $q4 == "Y" ]]; then
    score=$((score + 2))
    echo "   → +2 points for Argo Workflows"
fi

# Question 5
read -p "5. Will you have more than 5 sequential jobs? " q5
if [[ $q5 == "y" || $q5 == "Y" ]]; then
    score=$((score + 2))
    echo "   → +2 points for Argo Workflows"
fi

# Question 6
read -p "6. Do you need advanced retry logic (per-step, backoff)? " q6
if [[ $q6 == "y" || $q6 == "Y" ]]; then
    score=$((score + 2))
    echo "   → +2 points for Argo Workflows"
fi

# Question 7
read -p "7. Do you want to reuse workflow templates? " q7
if [[ $q7 == "y" || $q7 == "Y" ]]; then
    score=$((score + 1))
    echo "   → +1 point for Argo Workflows"
fi

# Question 8
read -p "8. Do you need scheduled workflows (cron)? " q8
if [[ $q8 == "y" || $q8 == "Y" ]]; then
    score=$((score + 1))
    echo "   → +1 point for Argo Workflows"
fi

# Question 9
read -p "9. Is your team comfortable with additional infrastructure? " q9
if [[ $q9 == "n" || $q9 == "N" ]]; then
    score=$((score - 3))
    echo "   → -3 points for Argo Workflows"
fi

# Question 10
read -p "10. Do you prefer simple, minimal setup? " q10
if [[ $q10 == "y" || $q10 == "Y" ]]; then
    score=$((score - 2))
    echo "   → -2 points for Argo Workflows"
fi

echo ""
echo "=================================================="
echo "Results"
echo "=================================================="
echo ""
echo "Your score: $score"
echo ""

if [ $score -ge 8 ]; then
    echo "✅ RECOMMENDATION: Use Argo Workflows"
    echo ""
    echo "Your requirements strongly favor Argo Workflows."
    echo "You need advanced orchestration features that are"
    echo "difficult to implement with regular Kubernetes Jobs."
    echo ""
    echo "Next steps:"
    echo "1. Run: ./install-argo.sh"
    echo "2. Read: ARGO_WORKFLOWS_GUIDE.md"
    echo "3. Deploy with: helm install ... --set argoWorkflow.enabled=true"
elif [ $score -ge 4 ]; then
    echo "⚖️  RECOMMENDATION: Consider Argo Workflows"
    echo ""
    echo "You have some requirements that benefit from Argo,"
    echo "but your current setup might be sufficient."
    echo ""
    echo "Consider:"
    echo "- Start with regular Jobs (current approach)"
    echo "- Migrate to Argo when complexity increases"
    echo "- Test Argo in a dev environment first"
    echo ""
    echo "To try Argo:"
    echo "1. Run: ./install-argo.sh"
    echo "2. Test in task-system-slave namespace first"
elif [ $score -ge 0 ]; then
    echo "✅ RECOMMENDATION: Stay with Regular Jobs + InitContainers"
    echo ""
    echo "Your requirements are well-served by the current"
    echo "implementation. Argo Workflows would add unnecessary"
    echo "complexity for your use case."
    echo ""
    echo "Your current setup is ideal because:"
    echo "- Simple sequential execution"
    echo "- Minimal infrastructure"
    echo "- Easy to understand and maintain"
    echo "- No learning curve"
else
    echo "✅ RECOMMENDATION: Definitely stay with Regular Jobs"
    echo ""
    echo "Argo Workflows is not a good fit for your needs."
    echo "Stick with your current Kubernetes Jobs + InitContainers"
    echo "approach. It's simpler and meets your requirements."
fi

echo ""
echo "=================================================="
echo "Current Implementation Benefits"
echo "=================================================="
echo ""
echo "✅ No additional infrastructure needed"
echo "✅ Built-in Kubernetes features"
echo "✅ Low learning curve"
echo "✅ Easy to debug with kubectl"
echo "✅ Works with standard Kubernetes RBAC"
echo ""

echo "=================================================="
echo "Argo Workflows Benefits"
echo "=================================================="
echo ""
echo "✅ Advanced workflow orchestration"
echo "✅ Web UI for monitoring"
echo "✅ Complex dependencies (DAG)"
echo "✅ Parallel execution support"
echo "✅ Conditional logic"
echo "✅ Per-step retry strategies"
echo "✅ Workflow templates for reusability"
echo "✅ Rich CLI for management"
echo ""

echo "For more details, see:"
echo "- ARGO_WORKFLOWS_GUIDE.md (comprehensive guide)"
echo "- ARGO_EXAMPLES.md (workflow patterns)"
echo "- ARGO_QUICKSTART.md (quick reference)"
echo ""
